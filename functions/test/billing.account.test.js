const assert = require('node:assert/strict');
const { before, beforeEach, after, test } = require('node:test');
const admin = require('firebase-admin');
const { createAccountService } = require('../billing/account_service');
const { projectAccount } = require('../billing/account_projection');

const projectId = 'demo-acueducto';
let app, db, service;
const actor = { uid: 'admin', nombre: 'Administrador' };
const meter = '10008';

function invoice(period, total, extra = {}) {
  return {
    id: meter, periodo: period, codigoUsuario: '25A', codigoContador: meter,
    nombreUsuario: 'Cliente de prueba', sector: 'sector 1',
    total, reconexion: 0, saldoAnterior: 0, valorPagado: 0,
    pagado: false, estado: 'facturado', lecturaAnterior: 108,
    lecturaActual: 114, consumoM3: 6,
    fechaGeneracion: admin.firestore.Timestamp.fromDate(new Date('2026-08-18T16:42:00Z')),
    fechaVencimiento: admin.firestore.Timestamp.fromDate(new Date('2026-09-01T05:00:00Z')),
    lineas: [{ descripcion: 'Cargo fijo', valorUnitario: total, cantidad: 1, valorTotal: total }],
    ...extra,
  };
}

async function seed({ payments = [], reversals = [] } = {}) {
  const batch = db.batch();
  for (const [period, total] of [['2026-06', 116000], ['2026-07', 27300], ['2026-08', 44100]]) {
    batch.set(db.doc(`periodos/${period}`), { id: period });
    batch.set(db.doc(`periodos/${period}/recibos/${meter}`), invoice(period, total));
    batch.set(db.doc(`periodos/${period}/consumos/${meter}`), {
      codigoUsuario: '25A', codigoContador: meter, periodoActual: period,
      lecturaAnterior: 108, lecturaActual: 114, consumoCalculado: 6,
      estado: 'facturado', facturado: true, pagado: false,
    });
    batch.set(db.doc(`cuentas_movimientos/factura_${period}_${meter}`), {
      id: `factura_${period}_${meter}`, tipo: 'factura', periodo: period,
      codigoUsuario: '25A', codigoContador: meter, valor: total,
    });
  }
  for (const [index, amount] of payments.entries()) {
    batch.set(db.doc(`cuentas_movimientos/initial_payment_${index}`), {
      id: `initial_payment_${index}`, tipo: 'pago', periodo: '2026-07',
      codigoUsuario: '25A', codigoContador: meter, valor: -amount,
      fecha: admin.firestore.Timestamp.fromDate(new Date('2026-07-26T18:09:00Z')),
      medioPagoId: 'nequi', medioPagoDescripcion: 'Nequi',
    });
  }
  for (const [index, amount] of reversals.entries()) {
    batch.set(db.doc(`cuentas_movimientos/initial_reversal_${index}`), {
      id: `initial_reversal_${index}`, tipo: 'reverso_pago', periodo: '2026-07',
      codigoUsuario: '25A', codigoContador: meter, valor: amount,
    });
  }
  await batch.commit();
}

before(async () => {
  assert.ok(process.env.FIRESTORE_EMULATOR_HOST, 'These tests require the Firestore emulator.');
  app = admin.initializeApp({ projectId }, 'billing-tests');
  db = app.firestore();
  service = createAccountService(db, admin);
});

beforeEach(async () => {
  const response = await fetch(`http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/${projectId}/databases/(default)/documents`, { method: 'DELETE' });
  assert.equal(response.ok, true);
});

after(async () => { await app?.delete(); });

async function pay({ mode = 'add', amount = 116000, requestId = 'payment-request-001', observations = '', confirmWarnings = true } = {}) {
  const data = { period: '2026-07', meter, mode, amount, observations, requestId };
  const proposal = await service.previewPayment(data);
  return service.applyPayment({ ...data, token: proposal.token, confirmWarnings }, actor);
}

async function receipt(period) {
  return (await db.doc(`periodos/${period}/recibos/${meter}`).get()).data();
}

test('25A: one payment of 116000 leaves July 27300 and August 71400', async () => {
  await seed();
  await pay();
  const july = await receipt('2026-07'), august = await receipt('2026-08');
  assert.equal(july.valorPagado, 116000);
  assert.equal(july.total + july.saldoAnterior - july.valorPagado, 27300);
  assert.equal(august.saldoAnterior, 27300);
  assert.equal(august.total + august.saldoAnterior, 71400);
  assert.equal(august.pagado, false);
  assert.equal(august.estado, 'en_mora');
  const reading = (await db.doc(`periodos/2026-07/consumos/${meter}`).get()).data();
  assert.equal(reading.valorPagado, july.valorPagado);
  assert.equal(reading.lecturaActual, 114);
});

test('regeneration recovers ledger payments and preserves them after a price change', async () => {
  await seed({ payments: [116000] });
  const candidate = invoice('2026-07', 40300);
  candidate.fechaGeneracion = candidate.fechaGeneracion.toDate().toISOString();
  candidate.fechaVencimiento = candidate.fechaVencimiento.toDate().toISOString();
  await service.saveInvoice({ period: '2026-07', meter, mode: 'regenerate', invoice: candidate }, actor);
  const july = await receipt('2026-07');
  assert.equal(july.valorPagado, 116000);
  assert.equal(july.fechaPago.toDate().toISOString(), '2026-07-26T18:09:00.000Z');
  assert.equal(july.medioPagoDescripcion, 'Nequi');
  assert.equal((await receipt('2026-08')).saldoAnterior, 40300);
  const payments = await db.collection('cuentas_movimientos').where('tipo', '==', 'pago').get();
  assert.equal(payments.size, 1);
});

test('a repeated amount warns, and can proceed only after confirmation', async () => {
  await seed({ payments: [116000] });
  const request = { period: '2026-07', meter, mode: 'add', amount: 116000,
    requestId: 'payment-duplicate-confirmed' };
  const proposal = await service.previewPayment(request);
  assert.ok(proposal.warnings.some((warning) => warning.includes('Ya existe un abono')));
  const unconfirmed = await service.applyPayment({ ...request, token: proposal.token }, actor);
  assert.equal(unconfirmed.requiresConfirmation, true);
  const confirmed = await service.applyPayment({ ...request, token: proposal.token, confirmWarnings: true }, actor);
  assert.equal(confirmed.paidAmount, 232000);
});

test('retrying the same operation does not create another payment', async () => {
  await seed();
  const request = { period: '2026-07', meter, mode: 'add', amount: 116000,
    requestId: 'payment-network-retry' };
  const proposal = await service.previewPayment(request);
  const payload = { ...request, token: proposal.token, confirmWarnings: true };
  const first = await service.applyPayment(payload, actor);
  const retried = await service.applyPayment(payload, actor);
  assert.deepEqual(first, retried);
  assert.equal((await db.collection('cuentas_movimientos').where('tipo', '==', 'pago').get()).size, 1);
});

test('correcting accumulated payments writes only the difference and reopens credit-paid invoices', async () => {
  await seed({ payments: [116000, 126000, 126000], reversals: [10000] });
  await pay({ mode: 'set', amount: 358000, observations: 'Valor anterior', requestId: 'first-normalize-values' });
  assert.equal((await receipt('2026-08')).pagado, true);
  await pay({ mode: 'set', amount: 116000, observations: 'Conservar únicamente el soporte válido', requestId: 'correct-total-116000' });
  const august = await receipt('2026-08');
  assert.equal(august.pagado, false);
  assert.equal(august.saldoAnterior, 27300);
  const reversals = await db.collection('cuentas_movimientos').where('tipo', '==', 'reverso_pago').get();
  assert.equal(reversals.size, 2);
  assert.ok(reversals.docs.some((doc) => doc.data().valor === 242000));
});

test('annulling a payment restores debt in all subsequent periods', async () => {
  await seed();
  await pay();
  await pay({ mode: 'reverse', amount: 0, observations: 'Anulación autorizada', requestId: 'reverse-payment-001' });
  assert.equal((await receipt('2026-07')).valorPagado, 0);
  assert.equal((await receipt('2026-08')).saldoAnterior, 143300);
  assert.equal((await receipt('2026-08')).pagado, false);
});

test('a changed account requests a new confirmation instead of applying an old proposal', async () => {
  await seed();
  const request = { period: '2026-07', meter, mode: 'add', amount: 116000,
    requestId: 'payment-stale-tab-001' };
  const old = await service.previewPayment(request);
  await pay({ amount: 10000, requestId: 'payment-other-tab-001' });
  const response = await service.applyPayment({ ...request, token: old.token, confirmWarnings: true }, actor);
  assert.equal(response.requiresConfirmation, true);
  assert.equal(response.preview.currentPaid, 10000);
  assert.equal((await receipt('2026-07')).valorPagado, 10000);
});

test('carried credit remains available after covering a zero-cash invoice', () => {
  const records = [invoice('2026-07', 27300), invoice('2026-08', 44100)];
  const ledger = [
    { periodo: '2026-07', tipo: 'factura', valor: 27300 },
    { periodo: '2026-07', tipo: 'pago', valor: -100000 },
    { periodo: '2026-08', tipo: 'factura', valor: 44100 },
  ];
  const result = projectAccount(records, ledger);
  assert.equal(result[1].saldoAnterior, -72700);
  assert.equal(result[1].valorPagado, 0);
  assert.equal(result[1].pagado, true);
});

test('concurrent submissions from two tabs require reconfirming the second payment', async () => {
  await seed();
  const base = { period: '2026-07', meter, mode: 'add', amount: 116000 };
  const proposal = await service.previewPayment(base);
  const results = await Promise.all(['concurrent-payment-a', 'concurrent-payment-b'].map((requestId) =>
    service.applyPayment({ ...base, requestId, token: proposal.token, confirmWarnings: true }, actor)));
  assert.equal(results.filter((result) => result.requiresConfirmation).length, 1);
  assert.equal((await receipt('2026-07')).valorPagado, 116000);
  assert.equal((await receipt('2026-08')).saldoAnterior, 27300);
});
