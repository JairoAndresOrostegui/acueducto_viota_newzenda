import 'package:flutter/material.dart';

import '../../../../core/presentation/text_formatters.dart';
import '../../../../theme/app_colors.dart';
import '../../../billing/invoices/data/invoice_firestore_service.dart';
import '../../../billing/invoices/domain/invoice.dart';
import '../../../billing/periods/data/billing_period_firestore_service.dart';
import '../../../billing/periods/domain/billing_period.dart';
import '../../../users/domain/app_user.dart';

class ConsumptionSuspensionsAdminPage extends StatefulWidget {
  const ConsumptionSuspensionsAdminPage({
    super.key,
    required this.currentUser,
    this.periodService,
    this.invoiceService,
  });

  final AppUser currentUser;
  final BillingPeriodFirestoreService? periodService;
  final InvoiceFirestoreService? invoiceService;

  @override
  State<ConsumptionSuspensionsAdminPage> createState() =>
      _ConsumptionSuspensionsAdminPageState();
}

class _ConsumptionSuspensionsAdminPageState
    extends State<ConsumptionSuspensionsAdminPage> {

  late final BillingPeriodFirestoreService _periodService =
      widget.periodService ?? BillingPeriodFirestoreService();
  late final InvoiceFirestoreService _invoiceService =
      widget.invoiceService ?? InvoiceFirestoreService();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  String _query = '';
  String _searchField = 'nombre';
  String _statusFilter = 'all';
  List<BillingPeriod> _periods = const [];
  BillingPeriod? _selectedPeriod;
  List<Invoice> _invoices = const [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPeriods();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPeriods() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final periods = await _periodService.fetchOperationalPeriods();
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

  Future<void> _suspendInvoice(Invoice invoice) async {
    if (_saving) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Suspender factura'),
        content: Text(
          'Se suspenderá a ${toDisplayUserName(invoice.nombreUsuario)}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Suspender'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    setState(() => _saving = true);
    try {
      await _invoiceService.suspendInvoice(
        invoice: invoice,
        actor: widget.currentUser,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Factura suspendida.')),
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
        SnackBar(content: Text('No fue posible suspender la factura: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _restoreInvoice(Invoice invoice) async {
    if (_saving) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quitar suspensión'),
        content: Text(
          'La factura de ${toDisplayUserName(invoice.nombreUsuario)} volverá a estado normal.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Quitar suspensión'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    setState(() => _saving = true);
    try {
      await _invoiceService.restoreSuspendedInvoice(
        invoice: invoice,
        actor: widget.currentUser,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Suspensión retirada.')),
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
        SnackBar(content: Text('No fue posible quitar la suspensión: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredInvoices = _filteredInvoices();
    final currentCount = _invoices.length;
    final upToDateCount =
        _invoices.where((item) => _suspensionStatus(item) == 'al_dia').length;
    final moraCount = _invoices
        .where((item) => _suspensionStatus(item) == 'en_mora')
        .length;
    final suspendidasCount =
        _invoices.where((item) => _suspensionStatus(item) == 'suspendido').length;

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
                totalCount: currentCount,
                upToDateCount: upToDateCount,
                moraCount: moraCount,
                suspendidasCount: suspendidasCount,
                statusFilter: _statusFilter,
                onPeriodChanged: (period) {
                  if (period != null) {
                    _loadInvoices(period);
                  }
                },
                onStatusFilterChanged: (value) {
                  setState(() => _statusFilter = value);
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                decoration: const InputDecoration(
                  labelText: 'Buscar facturas',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: 8),
              _SearchFieldSelector(
                selected: _searchField,
                onChanged: (value) => setState(() => _searchField = value),
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
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : filteredInvoices.isEmpty
                        ? Center(
                            child: Text(
                              _invoices.isEmpty
                                  ? 'No hay facturas para suspender en este periodo.'
                                  : 'No hay facturas que coincidan con la búsqueda.',
                            ),
                          )
                        : ListView.separated(
                            itemCount: filteredInvoices.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final invoice = filteredInvoices[index];
                              return _SuspensionCard(
                                invoice: invoice,
                                onSuspend: !invoice.estaSuspendido
                                    ? () => _suspendInvoice(invoice)
                                    : null,
                                onRestore: invoice.estaSuspendido
                                    ? () => _restoreInvoice(invoice)
                                    : null,
                              );
                            },
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

  List<Invoice> _filteredInvoices() {
    final query = _query.trim().toLowerCase();
    return _invoices.where((invoice) {
      if (!_matchesStatusFilter(invoice)) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      return switch (_searchField) {
        'codigoUsuario' => invoice.codigoUsuario.toLowerCase().contains(query),
        'contador' => invoice.codigoContador.toLowerCase().contains(query),
        _ => invoice.nombreUsuario.toLowerCase().contains(query),
      };
    }).toList();
  }

  bool _matchesStatusFilter(Invoice invoice) {
    return switch (_statusFilter) {
      'al_dia' => _suspensionStatus(invoice) == 'al_dia',
      'en_mora' => _suspensionStatus(invoice) == 'en_mora',
      'suspendido' => _suspensionStatus(invoice) == 'suspendido',
      _ => true,
    };
  }

  String _suspensionStatus(Invoice invoice) {
    if (invoice.estaSuspendido) {
      return 'suspendido';
    }
    return switch ((invoice.estadoPeriodoAnterior ?? '').trim().toLowerCase()) {
      'en_mora' => 'en_mora',
      'suspendido' => 'suspendido',
      _ => 'al_dia',
    };
  }
}

class _SearchFieldSelector extends StatelessWidget {
  const _SearchFieldSelector({
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
    required this.totalCount,
    required this.upToDateCount,
    required this.moraCount,
    required this.suspendidasCount,
    required this.statusFilter,
    required this.onPeriodChanged,
    required this.onStatusFilterChanged,
  });

  final List<BillingPeriod> periods;
  final BillingPeriod? selectedPeriod;
  final int totalCount;
  final int upToDateCount;
  final int moraCount;
  final int suspendidasCount;
  final String statusFilter;
  final ValueChanged<BillingPeriod?> onPeriodChanged;
  final ValueChanged<String> onStatusFilterChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final info = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Suspensiones',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Suspende facturas no pagadas. El periodo base 2025-12 no interviene en la cartera.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ChoiceChip(
                  label: Text('Todos: $totalCount'),
                  selected: statusFilter == 'all',
                  onSelected: (_) => onStatusFilterChanged('all'),
                ),
                ChoiceChip(
                  label: Text('Al día: $upToDateCount'),
                  selected: statusFilter == 'al_dia',
                  onSelected: (_) => onStatusFilterChanged('al_dia'),
                ),
                ChoiceChip(
                  label: Text('En mora: $moraCount'),
                  selected: statusFilter == 'en_mora',
                  onSelected: (_) => onStatusFilterChanged('en_mora'),
                ),
                ChoiceChip(
                  label: Text('Suspendidas: $suspendidasCount'),
                  selected: statusFilter == 'suspendido',
                  onSelected: (_) => onStatusFilterChanged('suspendido'),
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
                        child: Text(
                          period.nombre,
                          overflow: TextOverflow.ellipsis,
                        ),
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

class _SuspensionCard extends StatelessWidget {
  const _SuspensionCard({
    required this.invoice,
    required this.onSuspend,
    required this.onRestore,
  });

  final Invoice invoice;
  final VoidCallback? onSuspend;
  final VoidCallback? onRestore;

  @override
  Widget build(BuildContext context) {
    final status = invoice.estaSuspendido
        ? 'suspendido'
        : (invoice.estadoPeriodoAnterior ?? '').trim().toLowerCase();
    final statusText = switch (status) {
      'en_mora' => 'En mora',
      'suspendido' => 'Suspendida',
      _ => 'Al día',
    };
    final statusColor = switch (status) {
      'en_mora' => Colors.orange.shade800,
      'suspendido' => Colors.red.shade800,
      _ => Colors.green.shade800,
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
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
                'Periodo: ${invoice.periodo} · Total a pagar: ${_formatCurrency(invoice.totalAPagar)}',
              ),
              const SizedBox(height: 6),
              if (invoice.saldoAnterior != 0)
                Text(
                  invoice.saldoAnterior < 0
                      ? 'Saldo a favor: ${_formatCurrency(invoice.saldoAnterior.abs())}'
                      : 'Saldo anterior: ${_formatCurrency(invoice.saldoAnterior)}',
                ),
              const SizedBox(height: 6),
              Text(
                'Estado de cartera: $statusText',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          );
          final action = OutlinedButton.icon(
            onPressed: invoice.estaSuspendido ? onRestore : onSuspend,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 44),
            ),
            icon: Icon(
              invoice.estaSuspendido
                  ? Icons.play_circle_outline_rounded
                  : Icons.pause_circle_outline_rounded,
            ),
            label: Text(
              invoice.estaSuspendido ? 'Quitar suspensión' : 'Suspender',
            ),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                info,
                const SizedBox(height: 16),
                action,
              ],
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
