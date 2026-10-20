import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../payment_methods/domain/payment_method.dart';
import '../../domain/invoice.dart';

class InvoicePaymentResult {
  const InvoicePaymentResult({
    required this.mode,
    required this.amount,
    this.paymentMethod,
    this.observations,
  });

  final String mode;
  final int amount;
  final PaymentMethod? paymentMethod;
  final String? observations;
}

class InvoicePaymentDialog extends StatefulWidget {
  const InvoicePaymentDialog({
    super.key,
    required this.invoice,
    required this.paymentMethods,
  });

  final Invoice invoice;
  final List<PaymentMethod> paymentMethods;

  @override
  State<InvoicePaymentDialog> createState() => _InvoicePaymentDialogState();
}

class _InvoicePaymentDialogState extends State<InvoicePaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _observations = TextEditingController();
  String _mode = 'add';
  PaymentMethod? _method;

  @override
  void dispose() {
    _amount.dispose();
    _observations.dispose();
    super.dispose();
  }

  String _currency(int value) =>
      '\$${value.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.')}';

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 560,
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Registrar o corregir pago',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  '${widget.invoice.nombreUsuario} · ${widget.invoice.periodo}',
                ),
                const SizedBox(height: 12),
                Text(
                  'Total del recibo: ${_currency(widget.invoice.totalAPagar)}',
                ),
                Text(
                  'Abonos acumulados: ${_currency(widget.invoice.valorPagado ?? 0)}',
                ),
                Text('Pendiente: ${_currency(widget.invoice.saldoPendiente)}'),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  initialValue: _mode,
                  decoration: const InputDecoration(labelText: 'Operación'),
                  items: const [
                    DropdownMenuItem(value: 'add', child: Text('Nuevo abono')),
                    DropdownMenuItem(
                      value: 'set',
                      child: Text('Corregir total registrado'),
                    ),
                    DropdownMenuItem(
                      value: 'reverse',
                      child: Text('Anular abonos del recibo'),
                    ),
                  ],
                  onChanged: (mode) {
                    if (mode == null) return;
                    setState(() {
                      _mode = mode;
                      _amount.text = mode == 'set'
                          ? '${widget.invoice.valorPagado ?? 0}'
                          : '';
                    });
                  },
                ),
                const SizedBox(height: 12),
                Text(switch (_mode) {
                  'set' =>
                    'Indica cuánto debe quedar pagado en total. No se sumará como un abono adicional.',
                  'reverse' =>
                    'Se reversarán los abonos registrados y se recalcularán los recibos posteriores.',
                  _ =>
                    'Digita solo el dinero nuevo recibido. Se sumará a los abonos acumulados.',
                }),
                if (_mode != 'reverse') ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const ValueKey('payment-amount'),
                    controller: _amount,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: _mode == 'add'
                          ? 'Valor del nuevo abono'
                          : 'Total pagado correcto',
                    ),
                    validator: (value) {
                      final parsed = int.tryParse(value?.trim() ?? '');
                      if (parsed == null ||
                          parsed < 0 ||
                          (_mode == 'add' && parsed == 0)) {
                        return 'Ingresa un valor válido en pesos.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<PaymentMethod>(
                    isExpanded: true,
                    initialValue: _method,
                    decoration: const InputDecoration(
                      labelText: 'Medio de pago (opcional)',
                    ),
                    items: widget.paymentMethods
                        .map(
                          (method) => DropdownMenuItem(
                            value: method,
                            child: Text(
                              method.descripcion,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (method) => setState(() => _method = method),
                  ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  key: const ValueKey('payment-observations'),
                  controller: _observations,
                  minLines: 2,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: _mode == 'add'
                        ? 'Observaciones (opcional)'
                        : 'Motivo de la corrección o anulación',
                  ),
                  validator: (value) =>
                      _mode != 'add' && (value?.trim().isEmpty ?? true)
                      ? 'Indica el motivo de la operación.'
                      : null,
                ),
                const SizedBox(height: 24),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 12,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                    FilledButton(
                      onPressed: () {
                        if (!_formKey.currentState!.validate()) return;
                        Navigator.of(context).pop(
                          InvoicePaymentResult(
                            mode: _mode,
                            amount: _mode == 'reverse'
                                ? 0
                                : int.parse(_amount.text.trim()),
                            paymentMethod: _mode == 'reverse' ? null : _method,
                            observations: _observations.text.trim(),
                          ),
                        );
                      },
                      child: const Text('Continuar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
