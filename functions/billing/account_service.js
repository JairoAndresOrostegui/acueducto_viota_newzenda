const crypto = require('node:crypto');
const { HttpsError } = require('firebase-functions/v2/https');
const { number, paidAmount, projectAccount } = require('./account_projection');

function identifiers(data) {
  const period = String(data.period || '').trim();
  const meter = String(data.meter || '').trim();
  if (!/^\d{4}-(0[1-9]|1[0-2])$/.test(period) || period < '2026-01' ||
      !/^[A-Za-z0-9_-]+$/.test(meter)) {
    throw new HttpsError('invalid-argument', 'Periodo o contador inválido.');
  }
  return { period, meter };
}

function createAccountService(db, admin) {
  const timestamp = admin.firestore.Timestamp;

  async function readAccount(transaction, period, meter) {
    const periods = await transaction.get(db.collection('periodos'));
    const ids = [...new Set([...periods.docs.map((doc) => doc.id), period])]
      .filter((id) => id >= '2026-01').sort();
    const ledger = await transaction.get(db.collection('cuentas_movimientos')
      .where('codigoContador', '==', meter));
    const refs = ids.flatMap((id) => [
      db.doc(`periodos/${id}/recibos/${meter}`),
      db.doc(`periodos/${id}/consumos/${meter}`),
    ]);
    const snapshots = await transaction.getAll(...refs);
    const invoices = snapshots.filter((doc) => doc.exists && doc.ref.parent.id === 'recibos')
      .map((doc) => ({ ...doc.data(), periodo: doc.ref.parent.parent.id, id: doc.id }));
    const readings = new Map(snapshots.filter((doc) => doc.exists && doc.ref.parent.id === 'consumos')
      .map((doc) => [doc.ref.parent.parent.id, doc.data()]));
    const movements = ledger.docs.map((doc) => ({ ...doc.data(), id: doc.id }))
      .filter((item) => item.periodo >= '2026-01');
    return { invoices, readings, movements, snapshots, ledger };
  }

  function preview(account, data) {
    const { period } = identifiers(data);
    const invoice = account.invoices.find((item) => item.periodo === period);
    if (!invoice) throw new HttpsError('not-found', 'El recibo ya no existe.');
    if (!['add', 'set', 'reverse'].includes(data.mode)) {
      throw new HttpsError('invalid-argument', 'Selecciona la operación de pago.');
    }
    const amount = data.mode === 'reverse' ? 0 : Number(data.amount);
    if (!Number.isSafeInteger(amount) || amount < 0 || (data.mode === 'add' && amount === 0)) {
      throw new HttpsError('invalid-argument', 'Ingresa un valor válido en pesos.');
    }
    if (data.mode !== 'add' && !String(data.observations || '').trim()) {
      throw new HttpsError('invalid-argument', 'Indica el motivo de la corrección o anulación.');
    }
    const current = paidAmount(invoice, account.movements);
    const next = data.mode === 'add' ? current + amount : amount;
    const delta = next - current;
    const projected = projectAccount(account.invoices, account.movements, account.readings);
    const live = projected.find((item) => item.periodo === period);
    const pending = Math.max(number(live.total) + number(live.reconexion) + live.saldoAnterior - current, 0);
    const warnings = [];
    if (data.mode === 'add' && account.movements.some((item) =>
      item.tipo === 'pago' && item.periodo === period && -number(item.valor) === amount)) {
      warnings.push(`Ya existe un abono de $${amount.toLocaleString('es-CO')} en este recibo. Verifica el soporte antes de registrar otro.`);
    }
    if (delta > pending) {
      warnings.push('El nuevo importe supera el saldo pendiente y generará saldo a favor.');
    }
    if (current !== number(invoice.valorPagado)) {
      warnings.push('Los movimientos y el recibo tienen abonos diferentes. Se conservará el total de los movimientos al actualizar.');
    }
    if (data.mode !== 'add') warnings.push('Esta operación modifica el total pagado y recalcula los recibos posteriores.');
    const token = crypto.createHash('sha256').update(JSON.stringify({
      invoiceVersions: account.snapshots.map((doc) => [doc.ref.path, doc.updateTime?.toMillis() || 0]),
      ledgerVersions: account.ledger.docs.map((doc) => [doc.id, doc.updateTime.toMillis()]),
      mode: data.mode, amount,
    })).digest('hex');
    return { token, warnings, currentPaid: current, nextPaid: next, delta, pending,
      priorBalance: live.saldoAnterior, currentStatus: live.estado, settled: live.pagado,
      affectedPeriods: projected.filter((item) => item.periodo >= period).map((item) => item.periodo) };
  }

  function writeProjection(transaction, account, fromPeriod) {
    const projected = projectAccount(account.invoices, account.movements, account.readings);
    let count = 0;
    for (const invoice of projected.filter((item) => item.periodo >= fromPeriod)) {
      const payments = account.movements.filter((item) => item.periodo === invoice.periodo && item.tipo === 'pago')
        .sort((a, b) => (a.fecha?.toMillis?.() || 0) - (b.fecha?.toMillis?.() || 0));
      const last = payments.at(-1);
      const paid = invoice.valorPagado > 0;
      const paymentFields = {
        valorPagado: invoice.valorPagado,
        fechaPago: paid ? invoice.fechaPago || last?.fecha || null : null,
        medioPagoId: paid ? invoice.medioPagoId || last?.medioPagoId || null : null,
        medioPagoDescripcion: paid ? invoice.medioPagoDescripcion || last?.medioPagoDescripcion || null : null,
        observacionesPago: paid ? invoice.observacionesPago || last?.observaciones || null : null,
      };
      transaction.set(db.doc(`periodos/${invoice.periodo}/recibos/${invoice.codigoContador}`), {
        ...invoice, ...paymentFields,
      }, { merge: true });
      // Keep the original meter reading and capture metadata untouched.
      if (account.readings.has(invoice.periodo)) {
        transaction.set(db.doc(`periodos/${invoice.periodo}/consumos/${invoice.codigoContador}`), {
          ...paymentFields, estado: invoice.estado, pagado: invoice.pagado,
          facturado: true, reciboId: invoice.id,
        }, { merge: true });
      }
      count++;
    }
    return count;
  }

  async function previewPayment(data) {
    const { period, meter } = identifiers(data);
    return db.runTransaction(async (transaction) =>
      preview(await readAccount(transaction, period, meter), data));
  }

  async function applyPayment(data, actor) {
    const { period, meter } = identifiers(data);
    if (!/^[A-Za-z0-9_-]{10,100}$/.test(data.requestId || '')) {
      throw new HttpsError('invalid-argument', 'Identificador de operación inválido.');
    }
    const operation = db.doc(`operaciones_cuenta/${data.requestId}`);
    return db.runTransaction(async (transaction) => {
      const previous = await transaction.get(operation);
      if (previous.exists) {
        const saved = previous.data();
        if (saved.actorUid !== actor.uid || saved.period !== period || saved.meter !== meter) {
          throw new HttpsError('permission-denied', 'La operación pertenece a otra solicitud.');
        }
        return saved.result;
      }
      const account = await readAccount(transaction, period, meter);
      const proposal = preview(account, data);
      if (proposal.token !== data.token ||
          (proposal.warnings.length && data.confirmWarnings !== true)) {
        return { requiresConfirmation: true, preview: proposal };
      }
      const invoice = account.invoices.find((item) => item.periodo === period);
      const now = timestamp.now();
      const method = String(data.paymentMethodId || '').trim();
      let methodData = null;
      if (method && proposal.delta > 0) {
        if (method.includes('/')) throw new HttpsError('invalid-argument', 'Medio de pago inválido.');
        const methodDoc = await transaction.get(db.doc(`medios_pago/${method}`));
        if (!methodDoc.exists) throw new HttpsError('not-found', 'El medio de pago no existe.');
        methodData = methodDoc.data();
      }
      if (proposal.delta !== 0) {
        const movement = {
          id: `${proposal.delta > 0 ? 'pago' : 'reverso_pago'}_${period}_${meter}_${data.requestId}`,
          tipo: proposal.delta > 0 ? 'pago' : 'reverso_pago',
          codigoUsuario: invoice.codigoUsuario, codigoContador: meter,
          nombreUsuario: invoice.nombreUsuario, sector: invoice.sector || '',
          periodo: period, reciboId: invoice.id, valor: -proposal.delta,
          descripcion: proposal.delta > 0 ? `Pago recibido ${period}` : `Reverso de pago ${period}`,
          fecha: now, actorUid: actor.uid, actorNombre: actor.nombre,
          medioPagoId: methodData ? method : null,
          medioPagoDescripcion: methodData?.descripcion || null,
          observaciones: String(data.observations || '').trim() || null,
          operacionId: data.requestId,
        };
        account.movements.push(movement);
        transaction.set(db.doc(`cuentas_movimientos/${movement.id}`), movement);
        invoice.valorPagado = proposal.nextPaid;
        invoice.fechaPago = proposal.nextPaid > 0 ? now : null;
        invoice.medioPagoId = movement.medioPagoId;
        invoice.medioPagoDescripcion = movement.medioPagoDescripcion;
        invoice.observacionesPago = movement.observaciones;
      }
      const count = writeProjection(transaction, account, period);
      const result = { requiresConfirmation: false, updatedInvoices: count, paidAmount: proposal.nextPaid };
      transaction.set(operation, { actorUid: actor.uid, period, meter, mode: data.mode,
        amount: number(data.amount), fecha: now, result });
      return result;
    });
  }

  async function saveInvoice(data, actor) {
    const { period, meter } = identifiers(data);
    return db.runTransaction(async (transaction) => {
      const account = await readAccount(transaction, period, meter);
      const existing = account.invoices.find((item) => item.periodo === period);
      if (data.mode === 'create' && existing) return { skipped: true };
      if (data.mode !== 'create' && data.mode !== 'regenerate') {
        throw new HttpsError('invalid-argument', 'Operación de facturación inválida.');
      }
      if (data.mode === 'regenerate' && !existing) throw new HttpsError('not-found', 'El recibo ya no existe.');
      const current = existing && projectAccount(account.invoices, account.movements, account.readings)
        .find((item) => item.periodo === period);
      if (current?.pagado) return { skipped: true };
      const reading = account.readings.get(period);
      const candidate = data.invoice || {};
      if (!reading || reading.estado === 'bloqueado' ||
          candidate.codigoUsuario !== reading.codigoUsuario ||
          candidate.codigoContador !== meter || candidate.periodo !== period || candidate.id !== meter ||
          number(candidate.lecturaActual) !== number(reading.lecturaActual) ||
          number(candidate.lecturaAnterior) !== number(reading.lecturaAnterior) ||
          number(candidate.consumoM3) !== number(reading.consumoCalculado ??
            (number(reading.lecturaActual) - number(reading.lecturaAnterior)))) {
        throw new HttpsError('failed-precondition', 'La lectura cambió. Recarga el periodo antes de facturar.');
      }
      if (!Number.isSafeInteger(candidate.total) || candidate.total < 0 ||
          !Number.isSafeInteger(candidate.reconexion) || candidate.reconexion < 0 ||
          !Number.isSafeInteger(candidate.consumoM3) || candidate.consumoM3 < 0 ||
          !Array.isArray(candidate.lineas) || !candidate.lineas.length || candidate.lineas.some((line) =>
        !Number.isSafeInteger(line.valorTotal) || !Number.isSafeInteger(line.valorUnitario) ||
        !Number.isSafeInteger(line.cantidad) || line.cantidad <= 0 || line.valorUnitario < 0 ||
        line.valorTotal !== line.valorUnitario * line.cantidad) ||
        candidate.lineas.reduce((sum, line) => sum + line.valorTotal, 0) !== candidate.total) {
        throw new HttpsError('invalid-argument', 'Los cargos del recibo son inconsistentes.');
      }
      const invoice = { ...candidate, actorUid: actor.uid, actorNombre: actor.nombre,
        valorPagado: existing ? paidAmount(existing, account.movements) : 0,
        fechaPago: existing?.fechaPago || null, medioPagoId: existing?.medioPagoId || null,
        medioPagoDescripcion: existing?.medioPagoDescripcion || null,
        observacionesPago: existing?.observacionesPago || null,
      };
      for (const key of ['fechaGeneracion', 'fechaVencimiento']) {
        const date = new Date(candidate[key]);
        if (!Number.isFinite(date.getTime())) throw new HttpsError('invalid-argument', 'Fecha de recibo inválida.');
        invoice[key] = timestamp.fromDate(date);
      }
      const chargeId = `factura_${period}_${meter}`;
      account.movements = account.movements.filter((item) => item.id !== chargeId);
      const charge = { id: chargeId, tipo: 'factura', codigoUsuario: invoice.codigoUsuario,
        codigoContador: meter, nombreUsuario: invoice.nombreUsuario, sector: invoice.sector || '',
        periodo: period, reciboId: meter, valor: number(invoice.total) + number(invoice.reconexion),
        descripcion: `Factura ${period}`, fecha: invoice.fechaGeneracion,
        actorUid: actor.uid, actorNombre: actor.nombre,
      };
      account.movements.push(charge);
      account.invoices = account.invoices.filter((item) => item.periodo !== period).concat(invoice);
      transaction.set(db.doc(`cuentas_movimientos/${chargeId}`), charge, { merge: true });
      const count = writeProjection(transaction, account, period);
      return { skipped: false, updatedInvoices: count };
    });
  }

  return { previewPayment, applyPayment, saveInvoice };
}

module.exports = { createAccountService };
