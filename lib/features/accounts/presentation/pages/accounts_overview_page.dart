import 'package:flutter/material.dart';

import '../../../../core/presentation/text_formatters.dart';
import '../../../../theme/app_colors.dart';
import '../../../billing/invoices/data/invoice_firestore_service.dart';
import '../../../billing/invoices/domain/invoice.dart';
import '../../../billing/periods/data/billing_period_firestore_service.dart';
import '../../../billing/periods/domain/billing_period.dart';
import '../../data/account_movement_firestore_service.dart';
import '../../domain/account_movement.dart';

class AccountsOverviewPage extends StatefulWidget {
  const AccountsOverviewPage({
    super.key,
    this.periodService,
    this.invoiceService,
    this.accountMovementService,
  });

  final BillingPeriodFirestoreService? periodService;
  final InvoiceFirestoreService? invoiceService;
  final AccountMovementFirestoreService? accountMovementService;

  @override
  State<AccountsOverviewPage> createState() => _AccountsOverviewPageState();
}

class _AccountsOverviewPageState extends State<AccountsOverviewPage> {
  late final BillingPeriodFirestoreService _periodService =
      widget.periodService ?? BillingPeriodFirestoreService();
  late final InvoiceFirestoreService _invoiceService =
      widget.invoiceService ?? InvoiceFirestoreService();
  late final AccountMovementFirestoreService _accountMovementService =
      widget.accountMovementService ?? AccountMovementFirestoreService();

  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  String? _error;
  String _query = '';
  String _statusFilter = 'all';
  BillingPeriod? _selectedPeriod;
  List<BillingPeriod> _periods = const [];
  List<Invoice> _invoices = const [];
  List<AccountMovement> _movements = const [];

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
        _selectedPeriod = selected;
      });
      if (selected != null) {
        await _loadPeriod(selected);
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

  Future<void> _loadPeriod(BillingPeriod period) async {
    setState(() {
      _loading = true;
      _error = null;
      _selectedPeriod = period;
    });
    try {
      final results = await Future.wait([
        _invoiceService.fetchInvoicesForPeriod(period.id),
        _accountMovementService.fetchMovements(limit: 5000),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _invoices = results[0] as List<Invoice>;
        _movements = (results[1] as List<AccountMovement>)
            .where((item) => item.periodo.compareTo(period.id) <= 0)
            .toList();
      });
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

  @override
  Widget build(BuildContext context) {
    final rows = _filteredRows();
    final allRows = _buildRows();
    final compact = MediaQuery.sizeOf(context).width < 820;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(
          periods: _periods,
          selectedPeriod: _selectedPeriod,
          allRows: allRows,
          statusFilter: _statusFilter,
          onPeriodChanged: (period) {
            if (period != null) {
              _loadPeriod(period);
            }
          },
          onStatusChanged: (value) => setState(() => _statusFilter = value),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _query = value),
          decoration: const InputDecoration(
            labelText: 'Buscar por usuario, codigo o sector',
            prefixIcon: Icon(Icons.search_rounded),
          ),
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
              : rows.isEmpty
              ? Center(
                  child: Text(
                    _invoices.isEmpty
                        ? 'No hay recibos para este periodo.'
                        : 'No hay cuentas que coincidan con la busqueda.',
                  ),
                )
              : ListView.separated(
                  shrinkWrap: compact,
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => _AccountCard(row: rows[index]),
                ),
        ),
      ],
    );
  }

  List<_AccountRow> _buildRows() {
    final balances = <String, int>{};
    for (final movement in _movements) {
      final code = movement.codigoUsuario.trim().toUpperCase();
      if (code.isEmpty) {
        continue;
      }
      balances[code] = (balances[code] ?? 0) + movement.valor;
    }
    return _invoices.map((invoice) {
      return _AccountRow(
        invoice: invoice,
        accountBalance: balances[invoice.codigoUsuario.trim().toUpperCase()] ?? 0,
      );
    }).toList();
  }

  List<_AccountRow> _filteredRows() {
    final query = _query.trim().toLowerCase();
    return _buildRows().where((row) {
      if (_statusFilter == 'paid' && !row.isPaid) {
        return false;
      }
      if (_statusFilter == 'debt' && !row.isDebt) {
        return false;
      }
      if (_statusFilter == 'suspended' && !row.invoice.estaSuspendido) {
        return false;
      }
      if (_statusFilter == 'credit' && row.accountBalance >= 0) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      return row.searchText.contains(query);
    }).toList();
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.periods,
    required this.selectedPeriod,
    required this.allRows,
    required this.statusFilter,
    required this.onPeriodChanged,
    required this.onStatusChanged,
  });

  final List<BillingPeriod> periods;
  final BillingPeriod? selectedPeriod;
  final List<_AccountRow> allRows;
  final String statusFilter;
  final ValueChanged<BillingPeriod?> onPeriodChanged;
  final ValueChanged<String> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final paid = allRows.where((item) => item.isPaid).length;
    final debt = allRows.where((item) => item.isDebt).length;
    final suspended = allRows
        .where((item) => item.invoice.estaSuspendido)
        .length;
    final credit = allRows.where((item) => item.accountBalance < 0).length;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 260,
            child: DropdownButtonFormField<BillingPeriod>(
              isExpanded: true,
              initialValue: selectedPeriod,
              decoration: const InputDecoration(labelText: 'Periodo'),
              items: periods
                  .map(
                    (period) => DropdownMenuItem(
                      value: period,
                      child: Text(
                        _periodLabel(period),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: onPeriodChanged,
            ),
          ),
          ChoiceChip(
            label: Text('Todos (${allRows.length})'),
            selected: statusFilter == 'all',
            onSelected: (_) => onStatusChanged('all'),
          ),
          ChoiceChip(
            label: Text('Al dia ($paid)'),
            selected: statusFilter == 'paid',
            onSelected: (_) => onStatusChanged('paid'),
          ),
          ChoiceChip(
            label: Text('En mora ($debt)'),
            selected: statusFilter == 'debt',
            onSelected: (_) => onStatusChanged('debt'),
          ),
          ChoiceChip(
            label: Text('Suspendidos ($suspended)'),
            selected: statusFilter == 'suspended',
            onSelected: (_) => onStatusChanged('suspended'),
          ),
          ChoiceChip(
            label: Text('Saldo a favor ($credit)'),
            selected: statusFilter == 'credit',
            onSelected: (_) => onStatusChanged('credit'),
          ),
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.row});

  final _AccountRow row;

  @override
  Widget build(BuildContext context) {
    final invoice = row.invoice;
    final statusColor = invoice.estaSuspendido
        ? Colors.red.shade800
        : row.isPaid
        ? Colors.green.shade800
        : Colors.orange.shade800;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            toDisplayUserName(invoice.nombreUsuario),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Codigo: ${invoice.codigoUsuario} - Contador: ${invoice.codigoContador} - Sector: ${toDisplayText(invoice.sector)}',
          ),
          const SizedBox(height: 6),
          Text(
            'Total a pagar: ${_formatCurrency(invoice.totalAPagar)} - Pagado: ${_formatCurrency(invoice.valorPagado ?? 0)} - Pendiente: ${_formatCurrency(invoice.saldoPendiente)}',
          ),
          const SizedBox(height: 6),
          Text(
            row.accountBalance < 0
                ? 'Cuenta con saldo a favor: ${_formatCurrency(row.accountBalance.abs())}'
                : 'Balance de cuenta: ${_formatCurrency(row.accountBalance)}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: row.accountBalance < 0
                      ? Colors.green.shade800
                      : AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Estado: ${toDisplayText(invoice.estado)}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _AccountRow {
  const _AccountRow({required this.invoice, required this.accountBalance});

  final Invoice invoice;
  final int accountBalance;

  bool get isPaid => invoice.pagado || invoice.saldoPendiente <= 0;
  bool get isDebt => !invoice.estaSuspendido && invoice.saldoPendiente > 0;

  String get searchText {
    return [
      invoice.nombreUsuario,
      invoice.codigoUsuario,
      invoice.codigoContador,
      invoice.sector,
      invoice.periodo,
      invoice.estado,
    ].join(' ').toLowerCase();
  }
}

String _periodLabel(BillingPeriod period) {
  return '${period.clave} - ${toDisplayText(period.nombre)}${period.vigente ? ' - Vigente' : ''}';
}

String _formatCurrency(int value) {
  final sign = value < 0 ? '-' : '';
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    final reverseIndex = digits.length - index;
    buffer.write(digits[index]);
    if (reverseIndex > 1 && reverseIndex % 3 == 1) {
      buffer.write('.');
    }
  }
  return '$sign\$${buffer.toString()}';
}
