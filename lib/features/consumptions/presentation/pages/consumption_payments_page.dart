import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/presentation/text_formatters.dart';
import '../../../../theme/app_colors.dart';
import '../../../billing/invoices/data/invoice_firestore_service.dart';
import '../../../billing/invoices/domain/invoice.dart';
import '../../../billing/payment_methods/data/payment_method_firestore_service.dart';
import '../../../billing/payment_methods/domain/payment_method.dart';
import '../../../billing/periods/data/billing_period_firestore_service.dart';
import '../../../billing/periods/domain/billing_period.dart';

class ConsumptionPaymentsPage extends StatefulWidget {
  const ConsumptionPaymentsPage({
    super.key,
    this.periodService,
    this.invoiceService,
    this.paymentMethodService,
  });

  final BillingPeriodFirestoreService? periodService;
  final InvoiceFirestoreService? invoiceService;
  final PaymentMethodFirestoreService? paymentMethodService;

  @override
  State<ConsumptionPaymentsPage> createState() => _ConsumptionPaymentsPageState();
}

class _ConsumptionPaymentsPageState extends State<ConsumptionPaymentsPage> {
  late final BillingPeriodFirestoreService _periodService =
      widget.periodService ?? BillingPeriodFirestoreService();
  late final InvoiceFirestoreService _invoiceService =
      widget.invoiceService ?? InvoiceFirestoreService();
  late final PaymentMethodFirestoreService _paymentMethodService =
      widget.paymentMethodService ?? PaymentMethodFirestoreService();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<BillingPeriod> _periods = const [];
  BillingPeriod? _selectedPeriod;
  List<Invoice> _invoices = const [];
  List<PaymentMethod> _paymentMethods = const [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _periodService.fetchPeriods(),
        _paymentMethodService.fetchItems(),
      ]);
      final periods = results[0] as List<BillingPeriod>;
      final selected = periods.isEmpty
          ? null
          : periods.firstWhere(
              (item) => item.vigente,
              orElse: () => periods.first,
            );
      setState(() {
        _periods = periods;
        _paymentMethods = results[1] as List<PaymentMethod>;
        _selectedPeriod = selected;
      });
      if (selected != null) {
        await _loadInvoices(selected);
      }
    } catch (error) {
      setState(() => _error = '$error');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadInvoices(BillingPeriod period) async {
    setState(() {
      _loading = true;
      _error = null;
      _selectedPeriod = period;
    });
    try {
      final invoices = await _invoiceService.fetchInvoicesForPeriod(period.id);
      setState(() => _invoices = invoices);
    } catch (error) {
      setState(() => _error = '$error');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openPaymentDialog(Invoice invoice) async {
    final result = await showDialog<_PaymentResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _PaymentDialog(
        invoice: invoice,
        paymentMethods: _paymentMethods,
      ),
    );
    if (result == null) {
      return;
    }

    setState(() => _saving = true);
    try {
      await _invoiceService.updatePaymentStatus(
        invoice: invoice,
        paid: result.paid,
        paidAmount: result.paidAmount,
        paymentMethod: result.paymentMethod,
        observations: result.observations,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.paid
                ? 'Pago registrado con valor guardado en la base de datos.'
                : 'Recibo marcado como no pagado.',
          ),
        ),
      );
      final period = _selectedPeriod;
      if (period != null) {
        await _loadInvoices(period);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No fue posible actualizar el pago: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AbsorbPointer(
          absorbing: _saving,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(
                periods: _periods,
                selectedPeriod: _selectedPeriod,
                paidCount: _invoices.where((item) => item.pagado).length,
                pendingCount: _invoices.where((item) => !item.pagado).length,
                onPeriodChanged: (period) {
                  if (period != null) {
                    _loadInvoices(period);
                  }
                },
              ),
              const SizedBox(height: 16),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_error!, style: TextStyle(color: Colors.red.shade800)),
                ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _invoices.isEmpty
                        ? const Center(
                            child: Text(
                              'No hay recibos facturados para este periodo.',
                            ),
                          )
                        : ListView.separated(
                            itemCount: _invoices.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 12),
                            itemBuilder: (context, index) => _PaymentCard(
                              invoice: _invoices[index],
                              onUpdate: () => _openPaymentDialog(_invoices[index]),
                            ),
                          ),
              ),
            ],
          ),
        ),
        if (_saving)
          Positioned.fill(
            child: ColoredBox(
              color: AppColors.textPrimary.withValues(alpha: 0.16),
              child: const Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.periods,
    required this.selectedPeriod,
    required this.paidCount,
    required this.pendingCount,
    required this.onPeriodChanged,
  });

  final List<BillingPeriod> periods;
  final BillingPeriod? selectedPeriod;
  final int paidCount;
  final int pendingCount;
  final ValueChanged<BillingPeriod?> onPeriodChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final info = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Registrar pagos', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Selecciona un periodo y registra el valor pagado de cada recibo.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                Chip(label: Text('Pagados: $paidCount')),
                Chip(label: Text('Pendientes: $pendingCount')),
              ],
            ),
          ],
        );
        final picker = SizedBox(
          width: 260,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Periodo', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              DropdownButtonFormField<BillingPeriod>(
                isExpanded: true,
                initialValue: selectedPeriod,
                decoration: const InputDecoration(
                  hintText: 'Selecciona un periodo',
                ),
                items: periods
                    .map(
                      (period) => DropdownMenuItem(
                        value: period,
                        child: Text(_periodLabel(period)),
                      ),
                    )
                    .toList(),
                onChanged: onPeriodChanged,
              ),
            ],
          ),
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [info, const SizedBox(height: 16), picker],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: info),
            const SizedBox(width: 16),
            picker,
          ],
        );
      },
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({
    required this.invoice,
    required this.onUpdate,
  });

  final Invoice invoice;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    final statusColor = invoice.pagado ? Colors.green.shade800 : Colors.orange.shade800;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: invoice.pagado ? Colors.green.shade200 : Colors.orange.shade200,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final info = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                toDisplayUserName(invoice.nombreUsuario),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text('Codigo usuario: ${invoice.codigoUsuario} · Contador: ${invoice.codigoContador}'),
              const SizedBox(height: 6),
              Text('Total recibo: ${_formatCurrency(invoice.total)} · Vence: ${_formatDate(invoice.fechaVencimiento)}'),
              const SizedBox(height: 6),
              Text(
                invoice.pagado
                    ? 'Estado: pagado · Valor pagado: ${_formatCurrency(invoice.valorPagado ?? invoice.total)}'
                    : 'Estado: facturado pendiente de pago',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: statusColor,
                ),
              ),
              if (!invoice.pagado) ...[
                const SizedBox(height: 6),
                Text(
                  'Valor a registrar: ${_formatCurrency(invoice.total)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
              if ((invoice.medioPagoDescripcion ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('Medio de pago: ${invoice.medioPagoDescripcion}'),
              ],
            ],
          );
          final action = ElevatedButton.icon(
            onPressed: onUpdate,
            style: ElevatedButton.styleFrom(minimumSize: const Size(0, 44)),
            icon: Icon(invoice.pagado ? Icons.undo_rounded : Icons.payments_rounded),
            label: Text(invoice.pagado ? 'Cambiar estado' : 'Registrar pago'),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [info, const SizedBox(height: 16), action],
            );
          }
          return Row(
            children: [
              Expanded(child: info),
              const SizedBox(width: 12),
              action,
            ],
          );
        },
      ),
    );
  }
}

class _PaymentDialog extends StatefulWidget {
  const _PaymentDialog({
    required this.invoice,
    required this.paymentMethods,
  });

  final Invoice invoice;
  final List<PaymentMethod> paymentMethods;

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  late bool _paid = widget.invoice.pagado;
  PaymentMethod? _paymentMethod;
  final TextEditingController _valueController = TextEditingController();
  final TextEditingController _observationsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _valueController.text = '${widget.invoice.valorPagado ?? widget.invoice.total}';
    _observationsController.text = widget.invoice.observacionesPago ?? '';
    if ((widget.invoice.medioPagoId ?? '').isNotEmpty) {
      final matches = widget.paymentMethods.where(
        (item) => item.id == widget.invoice.medioPagoId,
      );
      if (matches.isNotEmpty) {
        _paymentMethod = matches.first;
      }
    }
  }

  @override
  void dispose() {
    _valueController.dispose();
    _observationsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Actualizar pago', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(
                  '${toDisplayUserName(widget.invoice.nombreUsuario)} · ${_formatCurrency(widget.invoice.total)}',
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  value: _paid,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Usuario pago este recibo'),
                  onChanged: (value) => setState(() => _paid = value),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Valor del recibo',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatCurrency(widget.invoice.total),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _paid
                            ? 'El valor pagado se guardara en recibos y consumos.'
                            : 'Activa el pago para registrar el valor recibido.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (_paid) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _valueController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Valor pagado',
                      helperText: 'Este valor queda guardado en la base de datos.',
                    ),
                    validator: (value) {
                      if (!_paid) {
                        return null;
                      }
                      final amount = int.tryParse((value ?? '').trim());
                      if (amount == null || amount <= 0) {
                        return 'Ingresa un valor pagado valido.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<PaymentMethod>(
                    isExpanded: true,
                    initialValue: _paymentMethod,
                    decoration: const InputDecoration(
                      labelText: 'Medio de pago (opcional)',
                    ),
                    items: widget.paymentMethods
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(
                              item.descripcion,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _paymentMethod = value),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _observationsController,
                    minLines: 2,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Observaciones (opcional)',
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        if (_paid && !_formKey.currentState!.validate()) {
                          return;
                        }
                        Navigator.of(context).pop(
                          _PaymentResult(
                            paid: _paid,
                            paidAmount: _paid
                                ? int.tryParse(_valueController.text.trim())
                                : null,
                            paymentMethod: _paid ? _paymentMethod : null,
                            observations: _paid ? _observationsController.text.trim() : null,
                          ),
                        );
                      },
                      child: const Text('Guardar'),
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

class _PaymentResult {
  const _PaymentResult({
    required this.paid,
    this.paidAmount,
    this.paymentMethod,
    this.observations,
  });

  final bool paid;
  final int? paidAmount;
  final PaymentMethod? paymentMethod;
  final String? observations;
}

String _periodLabel(BillingPeriod period) {
  return '${period.clave} · ${toDisplayText(period.nombre)}${period.vigente ? ' · Vigente' : ''}';
}

String _formatDate(DateTime value) {
  return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}

String _formatCurrency(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    final reverseIndex = digits.length - index;
    buffer.write(digits[index]);
    if (reverseIndex > 1 && reverseIndex % 3 == 1) {
      buffer.write('.');
    }
  }
  return '\$${buffer.toString()}';
}
