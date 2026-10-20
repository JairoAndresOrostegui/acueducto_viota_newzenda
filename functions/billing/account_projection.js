const number = (value) => Number.isSafeInteger(Number(value)) ? Number(value) : 0;

function paidAmount(invoice, movements) {
  const payments = movements.filter((item) =>
    item.periodo === invoice.periodo && ['pago', 'reverso_pago'].includes(item.tipo));
  const amount = payments.length
    ? -payments.reduce((sum, item) => sum + number(item.valor), 0)
    : number(invoice.valorPagado);
  return amount === 0 ? 0 : amount;
}

// Reconstruct every carry-forward from the ledger; never sum invoice totals
// that already include balances from previous periods.
function projectAccount(invoices, movements, readings = new Map()) {
  const ordered = [...invoices].sort((a, b) => a.periodo.localeCompare(b.periodo));
  let manualSuspension = false;
  return ordered.map((invoice, index) => {
    const prior = movements.filter((item) => item.periodo < invoice.periodo)
      .reduce((sum, item) => sum + number(item.valor), 0);
    const paid = paidAmount(invoice, movements);
    if (paid < 0) throw new Error('Los reversos superan los pagos de este recibo.');
    const remaining = number(invoice.total) + number(invoice.reconexion) + prior - paid;
    const settled = remaining <= 0;
    const reading = readings.get(invoice.periodo);
    const detail = reading?.detalleEstado || '';
    if (detail.startsWith('Suspendido por ')) manualSuspension = true;
    if (detail.startsWith('Suspension levantada')) manualSuspension = false;
    if (settled) manualSuspension = false;
    // Payments cover the oldest debt first. Count only prior periods still
    // outstanding after this payment, rather than obsolete invoice flags.
    let priorDebt = Math.max(prior - paid, 0);
    let unpaidPeriods = 0;
    for (let previous = index - 1; previous >= 0 && priorDebt > 0; previous--) {
      const charge = number(ordered[previous].total) + number(ordered[previous].reconexion);
      if (charge <= 0) continue;
      unpaidPeriods++;
      priorDebt -= charge;
    }
    const status = settled ? 'pagado'
      : manualSuspension || unpaidPeriods >= 2 ? 'suspendido'
        : prior > 0 || paid > 0 ? 'en_mora' : 'facturado';
    const projected = {
      ...invoice,
      saldoAnterior: prior,
      valorPagado: paid,
      pagado: settled,
      estado: status,
      estadoPeriodoAnterior: prior <= paid ? 'al_dia'
        : unpaidPeriods >= 2 ? 'suspendido' : 'en_mora',
    };
    return projected;
  });
}

module.exports = { number, paidAmount, projectAccount };
