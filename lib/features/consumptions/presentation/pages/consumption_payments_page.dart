import 'package:flutter/material.dart';
import '../../../billing/invoices/data/billing_account_functions_service.dart';
import '../../../billing/invoices/presentation/widgets/invoice_payment_dialog.dart';

import '../../../../core/presentation/text_formatters.dart';
import '../../../../theme/app_colors.dart';
import '../../../billing/invoices/data/invoice_firestore_service.dart';
import '../../../billing/invoices/domain/invoice.dart';
import '../../../billing/payment_methods/data/payment_method_firestore_service.dart';
import '../../../billing/payment_methods/domain/payment_method.dart';
import '../../../billing/periods/data/billing_period_firestore_service.dart';
import '../../../billing/periods/domain/billing_period.dart';
import '../../../users/domain/app_user.dart';

class ConsumptionPaymentsPage extends StatefulWidget {
  const ConsumptionPaymentsPage({
    super.key,
    required this.currentUser,
    this.periodService,
    this.invoiceService,
    this.paymentMethodService,
  });

  final AppUser currentUser;
  final BillingPeriodFirestoreService? periodService;
  final InvoiceFirestoreService? invoiceService;
  final PaymentMethodFirestoreService? paymentMethodService;

  @override
  State<ConsumptionPaymentsPage> createState() =>
      _ConsumptionPaymentsPageState();
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
  String _savingMessage = 'Actualizando pagos y recibos posteriores…';
  String? _error;
  String _query = '';
  String _searchField = 'nombre';
  String _paymentStatusFilter = 'all';
  List<BillingPeriod> _periods = const [];
  BillingPeriod? _selectedPeriod;
  List<Invoice> _invoices = const [];
  List<PaymentMethod> _paymentMethods = const [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _periodService.fetchOperationalPeriods(),
        _paymentMethodService.fetchItems(),
      ]);
      final periods = results[0] as List<BillingPeriod>;
      final paymentMethods = results[1] as List<PaymentMethod>;
      final selected = periods.isEmpty
          ? null
          : periods.firstWhere(
              (item) => item.vigente,
              orElse: () => periods.first,
            );
      if (!mounted) {
        return;
      }
      setState(() {
        _periods = periods;
        _paymentMethods =
            paymentMethods
                .where((item) => item.descripcion.trim().isNotEmpty)
                .toList()
              ..sort((a, b) => a.descripcion.compareTo(b.descripcion));
        _selectedPeriod = periods.contains(selected)
            ? selected
            : (periods.isEmpty ? null : periods.first);
      });
      if (_selectedPeriod != null) {
        await _loadInvoices(_selectedPeriod!);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = '$error');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadInvoices(BillingPeriod period) async {
    if (!mounted) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _selectedPeriod = period;
    });
    try {
      final invoices = await _invoiceService.fetchInvoicesForPeriod(period.id);
      if (!mounted) {
        return;
      }
      setState(() => _invoices = invoices);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = '$error');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openPaymentDialog(Invoice invoice) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _savingMessage = 'Consultando los abonos actuales…';
    });
    try {
      final base = {'period': invoice.periodo, 'meter': invoice.codigoContador};
      final current = await _invoiceService.previewPayment({
        ...base,
        'mode': 'add',
        'amount': 1,
      });
      if (!mounted) return;
      setState(() => _saving = false);
      final result = await showDialog<InvoicePaymentResult>(
        context: context,
        barrierDismissible: false,
        builder: (context) => InvoicePaymentDialog(
          invoice: invoice.copyWith(
            valorPagado: current.currentPaid,
            saldoAnterior: current.priorBalance,
            estado: current.currentStatus,
            pagado: current.settled,
          ),
          paymentMethods: _paymentMethods,
        ),
      );
      if (result == null || !mounted) return;
      setState(() {
        _saving = true;
        _savingMessage = 'Validando el pago y calculando los saldos…';
      });
      final request = <String, dynamic>{
        ...base,
        'mode': result.mode,
        'amount': result.amount,
        'paymentMethodId': result.paymentMethod?.id,
        'observations': result.observations,
        'requestId': _invoiceService.createPaymentRequestId(),
      };
      var proposal = await _invoiceService.previewPayment(request);
      var changed = false;
      while (mounted) {
        if (proposal.warnings.isNotEmpty || changed) {
          final confirmed = await _confirmPayment(proposal, changed: changed);
          if (confirmed != true || !mounted) return;
        }
        setState(
          () => _savingMessage =
              'Guardando el pago y actualizando los recibos posteriores…',
        );
        final response = await _invoiceService.applyPayment({
          ...request,
          'token': proposal.token,
          'confirmWarnings': true,
        });
        if (response['requiresConfirmation'] == true) {
          proposal = PaymentPreview.fromMap(
            Map<String, dynamic>.from(response['preview'] as Map),
          );
          changed = true;
          continue;
        }
        if (!mounted) return;
        setState(() => _savingMessage = 'Cargando la cuenta actualizada…');
        if (_selectedPeriod != null) await _loadInvoices(_selectedPeriod!);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Operación guardada. Recibos actualizados: ${response['updatedInvoices']}.',
            ),
          ),
        );
        break;
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No fue posible actualizar el pago: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool?> _confirmPayment(
    PaymentPreview preview, {
    required bool changed,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Revisar operación de pago'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (changed)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'La cuenta cambió mientras se revisaba. Confirma los valores actualizados.',
                  ),
                ),
              for (final warning in preview.warnings)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(warning),
                ),
              Text(
                'Pagado actualmente: ${_formatCurrency(preview.currentPaid)}',
              ),
              Text(
                'Total pagado después de guardar: ${_formatCurrency(preview.nextPaid)}',
              ),
              const SizedBox(height: 12),
              Text(
                'Se actualizarán los periodos: ${preview.affectedPeriods.join(', ')}.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirmar y continuar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 760;
    final filteredInvoices = _filteredInvoices();
    final paidCount = _invoices.where((item) => item.pagado).length;
    final pendingCount = _invoices.where((item) => !item.pagado).length;
    final totalCount = paidCount + pendingCount;
    final invoicesList = _loading
        ? const Center(child: CircularProgressIndicator())
        : filteredInvoices.isEmpty
        ? Center(
            child: Text(
              _invoices.isEmpty
                  ? 'No hay recibos facturados para este periodo.'
                  : 'No hay recibos que coincidan con la busqueda.',
            ),
          )
        : ListView.separated(
            shrinkWrap: compact,
            physics: compact
                ? const NeverScrollableScrollPhysics()
                : const AlwaysScrollableScrollPhysics(),
            itemCount: filteredInvoices.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final invoice = filteredInvoices[index];
              return _PaymentCard(
                invoice: invoice,
                onUpdate: () => _openPaymentDialog(invoice),
              );
            },
          );

    return Stack(
      children: [
        AbsorbPointer(
          absorbing: _saving,
          child: compact
              ? SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Header(
                        periods: _periods,
                        selectedPeriod: _selectedPeriod,
                        paidCount: paidCount,
                        pendingCount: pendingCount,
                        totalCount: totalCount,
                        paymentStatusFilter: _paymentStatusFilter,
                        onPeriodChanged: (period) {
                          if (period != null) {
                            _loadInvoices(period);
                          }
                        },
                        onPaymentStatusChanged: (value) {
                          setState(() => _paymentStatusFilter = value);
                        },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _searchController,
                        onChanged: (value) => setState(() => _query = value),
                        decoration: const InputDecoration(
                          labelText: 'Buscar en pagos',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _PaymentSearchFieldSelector(
                        selected: _searchField,
                        onChanged: (value) =>
                            setState(() => _searchField = value),
                      ),
                      const SizedBox(height: 16),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            _error!,
                            style: TextStyle(color: Colors.red.shade800),
                          ),
                        ),
                      invoicesList,
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Header(
                      periods: _periods,
                      selectedPeriod: _selectedPeriod,
                      paidCount: paidCount,
                      pendingCount: pendingCount,
                      totalCount: totalCount,
                      paymentStatusFilter: _paymentStatusFilter,
                      onPeriodChanged: (period) {
                        if (period != null) {
                          _loadInvoices(period);
                        }
                      },
                      onPaymentStatusChanged: (value) {
                        setState(() => _paymentStatusFilter = value);
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _searchController,
                      onChanged: (value) => setState(() => _query = value),
                      decoration: const InputDecoration(
                        labelText: 'Buscar en pagos',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _PaymentSearchFieldSelector(
                      selected: _searchField,
                      onChanged: (value) =>
                          setState(() => _searchField = value),
                    ),
                    const SizedBox(height: 16),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          _error!,
                          style: TextStyle(color: Colors.red.shade800),
                        ),
                      ),
                    Expanded(child: invoicesList),
                  ],
                ),
        ),
        if (_saving)
          Positioned.fill(
            child: ColoredBox(
              color: AppColors.textPrimary.withValues(alpha: 0.16),
              child: Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(_savingMessage, textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  List<Invoice> _filteredInvoices() {
    final query = _query.trim().toLowerCase();
    return _invoices.where((invoice) {
      if (!_matchesStatusFilter(invoice)) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      return _matchesSearch(invoice, query);
    }).toList();
  }

  bool _matchesSearch(Invoice invoice, String query) {
    return switch (_searchField) {
      'codigoUsuario' => invoice.codigoUsuario.toLowerCase().contains(query),
      'contador' => invoice.codigoContador.toLowerCase().contains(query),
      _ => invoice.nombreUsuario.toLowerCase().contains(query),
    };
  }

  bool _matchesStatusFilter(Invoice invoice) {
    return switch (_paymentStatusFilter) {
      'paid' => invoice.pagado,
      'pending' => !invoice.pagado,
      _ => true,
    };
  }
}

class _PaymentSearchFieldSelector extends StatelessWidget {
  const _PaymentSearchFieldSelector({
    required this.selected,
    required this.onChanged,
  });

  static const _options = [
    ('nombre', 'Nombre'),
    ('codigoUsuario', 'Codigo usuario'),
    ('contador', 'Codigo contador'),
  ];

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return RadioGroup<String>(
      groupValue: selected,
      onChanged: (value) {
        if (value != null) {
          onChanged(value);
        }
      },
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final option in _options)
            InkWell(
              onTap: () => onChanged(option.$1),
              borderRadius: BorderRadius.circular(20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Radio<String>(
                    value: option.$1,
                    visualDensity: VisualDensity.compact,
                  ),
                  Text(option.$2),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.periods,
    required this.selectedPeriod,
    required this.paidCount,
    required this.pendingCount,
    required this.totalCount,
    required this.paymentStatusFilter,
    required this.onPeriodChanged,
    required this.onPaymentStatusChanged,
  });

  final List<BillingPeriod> periods;
  final BillingPeriod? selectedPeriod;
  final int paidCount;
  final int pendingCount;
  final int totalCount;
  final ValueChanged<BillingPeriod?> onPeriodChanged;
  final String paymentStatusFilter;
  final ValueChanged<String> onPaymentStatusChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final info = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Registrar pagos',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
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
                ChoiceChip(
                  label: Text('Todos ($totalCount)'),
                  selected: paymentStatusFilter == 'all',
                  onSelected: (_) => onPaymentStatusChanged('all'),
                ),
                ChoiceChip(
                  label: Text('Pagados: $paidCount'),
                  selected: paymentStatusFilter == 'paid',
                  onSelected: (_) => onPaymentStatusChanged('paid'),
                ),
                ChoiceChip(
                  label: Text('Pendientes: $pendingCount'),
                  selected: paymentStatusFilter == 'pending',
                  onSelected: (_) => onPaymentStatusChanged('pending'),
                ),
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
  const _PaymentCard({required this.invoice, required this.onUpdate});

  final Invoice invoice;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    final statusColor = invoice.estaSuspendido
        ? Colors.red.shade800
        : invoice.pagado
        ? Colors.green.shade800
        : Colors.orange.shade800;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: invoice.estaSuspendido
              ? Colors.red.shade200
              : invoice.pagado
              ? Colors.green.shade200
              : Colors.orange.shade200,
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
              Text(
                'Codigo usuario: ${invoice.codigoUsuario} · Contador: ${invoice.codigoContador}',
              ),
              const SizedBox(height: 6),
              Text(
                'Total a pagar: ${_formatCurrency(invoice.totalAPagar)} · Vence: ${_formatDate(invoice.fechaVencimiento)}',
              ),
              const SizedBox(height: 6),
              if (invoice.saldoAnterior > 0)
                Text(
                  'Saldo anterior: ${_formatCurrency(invoice.saldoAnterior)}',
                ),
              if (invoice.saldoAnterior < 0)
                Text(
                  'Saldo a favor aplicado: ${_formatCurrency(invoice.saldoAnterior.abs())}',
                ),
              if (invoice.saldoAnterior != 0) const SizedBox(height: 6),
              Text(
                invoice.estaSuspendido
                    ? 'Estado: suspendido · Abonado: ${_formatCurrency(invoice.valorPagado ?? 0)} · Pendiente: ${_formatCurrency(invoice.saldoPendiente)}'
                    : invoice.pagado
                    ? 'Estado: pagado · Valor pagado: ${_formatCurrency(invoice.valorPagado ?? invoice.totalAPagar)}'
                    : (invoice.valorPagado ?? 0) > 0
                    ? 'Estado: abono registrado - Pagado: ${_formatCurrency(invoice.valorPagado ?? 0)} - Pendiente: ${_formatCurrency(invoice.saldoPendiente)}'
                    : 'Estado: facturado pendiente de pago',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: statusColor),
              ),
              if (!invoice.pagado) ...[
                const SizedBox(height: 6),
                Text(
                  'Saldo pendiente: ${_formatCurrency(invoice.saldoPendiente)}',
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
            icon: Icon(
              invoice.pagado ? Icons.undo_rounded : Icons.payments_rounded,
            ),
            label: const Text('Registrar o corregir pago'),
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
