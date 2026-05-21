import 'dart:typed_data';

import 'package:excel/excel.dart' as xls;
import 'package:flutter/material.dart';

import '../../../../core/presentation/text_formatters.dart';
import '../../../../theme/app_colors.dart';
import '../../../accounts/data/account_movement_firestore_service.dart';
import '../../../accounts/domain/account_movement.dart';
import '../../../billing/invoices/data/invoice_firestore_service.dart';
import '../../../billing/invoices/domain/invoice.dart';
import '../../../billing/periods/data/billing_period_firestore_service.dart';
import '../../../billing/periods/domain/billing_period.dart';
import '../../../consumptions/presentation/pages/consumption_reports_file_exporter_stub.dart'
    if (dart.library.html) '../../../consumptions/presentation/pages/consumption_reports_file_exporter_web.dart';

class PortfolioReportsPage extends StatefulWidget {
  const PortfolioReportsPage({
    super.key,
    this.periodService,
    this.invoiceService,
    this.accountMovementService,
  });

  final BillingPeriodFirestoreService? periodService;
  final InvoiceFirestoreService? invoiceService;
  final AccountMovementFirestoreService? accountMovementService;

  @override
  State<PortfolioReportsPage> createState() => _PortfolioReportsPageState();
}

class _PortfolioReportsPageState extends State<PortfolioReportsPage> {
  late final BillingPeriodFirestoreService _periodService =
      widget.periodService ?? BillingPeriodFirestoreService();
  late final InvoiceFirestoreService _invoiceService =
      widget.invoiceService ?? InvoiceFirestoreService();
  late final AccountMovementFirestoreService _accountMovementService =
      widget.accountMovementService ?? AccountMovementFirestoreService();

  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  bool _hasGenerated = false;
  bool _allPeriods = false;
  String? _error;
  String _query = '';
  String _statusFilter = 'debt';
  BillingPeriod? _selectedPeriod;
  List<BillingPeriod> _periods = const [];
  List<Invoice> _invoices = const [];
  List<AccountMovement> _movements = const [];

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
        _selectedPeriod = selected;
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

  Future<void> _loadData() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final invoices = <Invoice>[];
      if (_allPeriods) {
        for (final period in _periods) {
          invoices.addAll(await _invoiceService.fetchInvoicesForPeriod(period.id));
        }
      } else if (_selectedPeriod != null) {
        invoices.addAll(
          await _invoiceService.fetchInvoicesForPeriod(_selectedPeriod!.id),
        );
      }
      final movements = await _accountMovementService.fetchMovements(limit: 5000);
      if (!mounted) {
        return;
      }
      setState(() {
        _invoices = invoices;
        _movements = movements;
        _hasGenerated = true;
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(
          periods: _periods,
          selectedPeriod: _selectedPeriod,
          allPeriods: _allPeriods,
          rows: allRows,
          statusFilter: _statusFilter,
          onPeriodChanged: (period) {
            setState(() {
              _selectedPeriod = period;
              _invoices = const [];
              _movements = const [];
              _hasGenerated = false;
            });
          },
          onAllPeriodsChanged: (value) {
            setState(() {
              _allPeriods = value;
              _invoices = const [];
              _movements = const [];
              _hasGenerated = false;
            });
          },
          onStatusChanged: (value) => setState(() => _statusFilter = value),
          onGenerate: _allPeriods || _selectedPeriod != null ? _loadData : null,
          onExport: !_hasGenerated || rows.isEmpty ? null : () => _export(rows),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _query = value),
          decoration: const InputDecoration(
            labelText: 'Buscar por usuario, codigo, contador o sector',
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
              : Center(
                  child: Text(
                    !_hasGenerated
                        ? 'Selecciona los filtros y genera el reporte.'
                        : rows.isEmpty
                        ? 'No hay registros que coincidan con el filtro.'
                        : 'Reporte generado. Puedes exportar el Excel.',
                    textAlign: TextAlign.center,
                  ),
                ),
        ),
      ],
    );
  }

  List<_PortfolioRow> _buildRows() {
    final balances = <String, int>{};
    final payments = <String, int>{};
    for (final movement in _movements) {
      final code = movement.codigoUsuario.trim().toUpperCase();
      if (code.isEmpty) {
        continue;
      }
      balances[code] = (balances[code] ?? 0) + movement.valor;
      if (movement.tipo == 'pago') {
        payments[code] = (payments[code] ?? 0) + movement.valor.abs();
      }
    }
    return _invoices
        .map(
          (invoice) => _PortfolioRow(
            invoice: invoice,
            accountBalance:
                balances[invoice.codigoUsuario.trim().toUpperCase()] ?? 0,
            totalPayments:
                payments[invoice.codigoUsuario.trim().toUpperCase()] ?? 0,
          ),
        )
        .toList();
  }

  List<_PortfolioRow> _filteredRows() {
    final query = _query.trim().toLowerCase();
    return _buildRows().where((row) {
      if (_statusFilter == 'debt' && row.pending <= 0) {
        return false;
      }
      if (_statusFilter == 'credit' && row.accountBalance >= 0) {
        return false;
      }
      if (_statusFilter == 'suspended' && !row.invoice.estaSuspendido) {
        return false;
      }
      if (_statusFilter == 'paid' && row.pending > 0) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      return row.searchText.contains(query);
    }).toList();
  }

  Future<void> _export(List<_PortfolioRow> rows) async {
    final excel = xls.Excel.createExcel();
    final sheet = excel['cartera'];
    sheet.appendRow([
      'periodo',
      'codigo_usuario',
      'nombre_usuario',
      'sector',
      'contador',
      'total_a_pagar',
      'valor_pagado',
      'saldo_pendiente',
      'balance_cuenta',
      'saldo_a_favor',
      'total_pagos_registrados',
      'estado',
      'fecha_vencimiento',
    ].map(xls.TextCellValue.new).toList());
    var totalAPagar = 0;
    var totalValorPagado = 0;
    var totalSaldoPendiente = 0;
    var totalBalanceCuenta = 0;
    var totalSaldoAFavor = 0;
    var totalPagosRegistrados = 0;
    for (final row in rows) {
      final invoice = row.invoice;
      final paidAmount = invoice.valorPagado ?? 0;
      final creditBalance = row.accountBalance < 0
          ? row.accountBalance.abs()
          : 0;
      totalAPagar += invoice.totalAPagar;
      totalValorPagado += paidAmount;
      totalSaldoPendiente += row.pending;
      totalBalanceCuenta += row.accountBalance;
      totalSaldoAFavor += creditBalance;
      totalPagosRegistrados += row.totalPayments;
      sheet.appendRow([
        xls.TextCellValue(invoice.periodo),
        xls.TextCellValue(invoice.codigoUsuario),
        xls.TextCellValue(invoice.nombreUsuario),
        xls.TextCellValue(invoice.sector),
        xls.TextCellValue(invoice.codigoContador),
        xls.IntCellValue(invoice.totalAPagar),
        xls.IntCellValue(paidAmount),
        xls.IntCellValue(row.pending),
        xls.IntCellValue(row.accountBalance),
        xls.IntCellValue(creditBalance),
        xls.IntCellValue(row.totalPayments),
        xls.TextCellValue(invoice.estado),
        xls.TextCellValue(_formatDate(invoice.fechaVencimiento)),
      ]);
    }
    sheet.appendRow([
      xls.TextCellValue('TOTAL'),
      xls.TextCellValue(''),
      xls.TextCellValue(''),
      xls.TextCellValue(''),
      xls.TextCellValue(''),
      xls.IntCellValue(totalAPagar),
      xls.IntCellValue(totalValorPagado),
      xls.IntCellValue(totalSaldoPendiente),
      xls.IntCellValue(totalBalanceCuenta),
      xls.IntCellValue(totalSaldoAFavor),
      xls.IntCellValue(totalPagosRegistrados),
      xls.TextCellValue(''),
      xls.TextCellValue(''),
    ]);
    excel.setDefaultSheet('cartera');
    final bytes = excel.encode();
    if (bytes == null) {
      return;
    }
    await saveConsumptionReportFile(
      bytes: Uint8List.fromList(bytes),
      fileName: 'reporte_cartera_${_allPeriods ? 'todos' : (_selectedPeriod?.id ?? 'periodo')}.xlsx',
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reporte de cartera descargado.')),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.periods,
    required this.selectedPeriod,
    required this.allPeriods,
    required this.rows,
    required this.statusFilter,
    required this.onPeriodChanged,
    required this.onAllPeriodsChanged,
    required this.onStatusChanged,
    required this.onGenerate,
    required this.onExport,
  });

  final List<BillingPeriod> periods;
  final BillingPeriod? selectedPeriod;
  final bool allPeriods;
  final List<_PortfolioRow> rows;
  final String statusFilter;
  final ValueChanged<BillingPeriod?> onPeriodChanged;
  final ValueChanged<bool> onAllPeriodsChanged;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback? onGenerate;
  final VoidCallback? onExport;

  @override
  Widget build(BuildContext context) {
    final pending = rows.fold<int>(0, (sum, item) => sum + item.pending);
    final credit = rows
        .where((item) => item.accountBalance < 0)
        .fold<int>(0, (sum, item) => sum + item.accountBalance.abs());
    final suspended = rows.where((item) => item.invoice.estaSuspendido).length;
    final paid = rows.fold<int>(0, (sum, item) => sum + (item.invoice.valorPagado ?? 0));
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Reporte de cartera', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          Wrap(
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
                  onChanged: allPeriods ? null : onPeriodChanged,
                ),
              ),
              FilterChip(
                label: const Text('Todos los periodos'),
                selected: allPeriods,
                onSelected: onAllPeriodsChanged,
              ),
              Chip(label: Text('Pendiente: ${_formatCurrency(pending)}')),
              Chip(label: Text('Pagado: ${_formatCurrency(paid)}')),
              Chip(label: Text('A favor: ${_formatCurrency(credit)}')),
              Chip(label: Text('Suspendidos: $suspended')),
              ElevatedButton.icon(
                onPressed: onGenerate,
                icon: const Icon(Icons.search_rounded),
                label: const Text('Generar'),
              ),
              OutlinedButton.icon(
                onPressed: onExport,
                icon: const Icon(Icons.download_rounded),
                label: const Text('Exportar Excel'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('En mora'),
                selected: statusFilter == 'debt',
                onSelected: (_) => onStatusChanged('debt'),
              ),
              ChoiceChip(
                label: const Text('Al dia'),
                selected: statusFilter == 'paid',
                onSelected: (_) => onStatusChanged('paid'),
              ),
              ChoiceChip(
                label: const Text('Saldo a favor'),
                selected: statusFilter == 'credit',
                onSelected: (_) => onStatusChanged('credit'),
              ),
              ChoiceChip(
                label: const Text('Suspendidos'),
                selected: statusFilter == 'suspended',
                onSelected: (_) => onStatusChanged('suspended'),
              ),
              ChoiceChip(
                label: const Text('Todos'),
                selected: statusFilter == 'all',
                onSelected: (_) => onStatusChanged('all'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PortfolioRow {
  const _PortfolioRow({
    required this.invoice,
    required this.accountBalance,
    required this.totalPayments,
  });

  final Invoice invoice;
  final int accountBalance;
  final int totalPayments;

  int get pending => invoice.saldoPendiente;

  String get searchText {
    return [
      invoice.nombreUsuario,
      invoice.codigoUsuario,
      invoice.codigoContador,
      invoice.sector,
      invoice.estado,
      invoice.periodo,
    ].join(' ').toLowerCase();
  }
}

String _periodLabel(BillingPeriod period) {
  return '${period.clave} - ${toDisplayText(period.nombre)}${period.vigente ? ' - Vigente' : ''}';
}

String _formatDate(DateTime value) {
  return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
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
