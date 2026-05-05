import 'dart:typed_data';

import 'package:excel/excel.dart' as xls;
import 'package:flutter/material.dart';

import '../../../../core/presentation/text_formatters.dart';
import '../../../../theme/app_colors.dart';
import '../../../billing/invoices/data/invoice_firestore_service.dart';
import '../../../billing/invoices/domain/invoice.dart';
import '../../../billing/periods/data/billing_period_firestore_service.dart';
import '../../../billing/periods/domain/billing_period.dart';
import '../../../consumptions/presentation/pages/consumption_reports_file_exporter_stub.dart'
    if (dart.library.html) '../../../consumptions/presentation/pages/consumption_reports_file_exporter_web.dart';

class BillingReportsPage extends StatefulWidget {
  const BillingReportsPage({
    super.key,
    this.periodService,
    this.invoiceService,
  });

  final BillingPeriodFirestoreService? periodService;
  final InvoiceFirestoreService? invoiceService;

  @override
  State<BillingReportsPage> createState() => _BillingReportsPageState();
}

class _BillingReportsPageState extends State<BillingReportsPage> {
  late final BillingPeriodFirestoreService _periodService =
      widget.periodService ?? BillingPeriodFirestoreService();
  late final InvoiceFirestoreService _invoiceService =
      widget.invoiceService ?? InvoiceFirestoreService();

  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  String? _error;
  String _query = '';
  String _statusFilter = 'all';
  BillingPeriod? _selectedPeriod;
  List<BillingPeriod> _periods = const [];
  List<Invoice> _invoices = const [];

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
      setState(() {
        _periods = periods;
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

  @override
  Widget build(BuildContext context) {
    final rows = _filteredInvoices();
    final compact = MediaQuery.sizeOf(context).width < 820;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(
          periods: _periods,
          selectedPeriod: _selectedPeriod,
          invoices: _invoices,
          statusFilter: _statusFilter,
          onPeriodChanged: (period) {
            if (period != null) {
              _loadInvoices(period);
            }
          },
          onStatusChanged: (value) => setState(() => _statusFilter = value),
          onExport: rows.isEmpty ? null : () => _export(rows),
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
              : rows.isEmpty
              ? Center(
                  child: Text(
                    _invoices.isEmpty
                        ? 'No hay recibos generados para este periodo.'
                        : 'No hay recibos que coincidan con el filtro.',
                  ),
                )
              : ListView.separated(
                  shrinkWrap: compact,
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) =>
                      _InvoiceReportCard(invoice: rows[index]),
                ),
        ),
      ],
    );
  }

  List<Invoice> _filteredInvoices() {
    final query = _query.trim().toLowerCase();
    return _invoices.where((invoice) {
      if (_statusFilter == 'paid' && !invoice.pagado) {
        return false;
      }
      if (_statusFilter == 'pending' && invoice.pagado) {
        return false;
      }
      if (_statusFilter == 'suspended' && !invoice.estaSuspendido) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      return [
        invoice.nombreUsuario,
        invoice.codigoUsuario,
        invoice.codigoContador,
        invoice.sector,
        invoice.estado,
      ].join(' ').toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _export(List<Invoice> invoices) async {
    final excel = xls.Excel.createExcel();
    final sheet = excel['facturacion'];
    sheet.appendRow([
      'periodo',
      'codigo_usuario',
      'nombre_usuario',
      'sector',
      'contador',
      'consumo_m3',
      'cargo_fijo',
      'valor_consumo',
      'valores_adicionales',
      'saldo_anterior',
      'saldo_a_favor_aplicado',
      'total_facturado',
      'total_a_pagar',
      'valor_pagado',
      'saldo_pendiente',
      'estado',
      'fecha_generacion',
      'fecha_vencimiento',
    ].map(xls.TextCellValue.new).toList());
    for (final invoice in invoices) {
      sheet.appendRow([
        invoice.periodo,
        invoice.codigoUsuario,
        invoice.nombreUsuario,
        invoice.sector,
        invoice.codigoContador,
        '${invoice.consumoM3}',
        '${invoice.cargoFijo}',
        '${_consumptionAmount(invoice)}',
        '${_additionalAmount(invoice)}',
        '${invoice.saldoAnterior > 0 ? invoice.saldoAnterior : 0}',
        '${invoice.saldoAnterior < 0 ? invoice.saldoAnterior.abs() : 0}',
        '${invoice.currentChargeTotal}',
        '${invoice.totalAPagar}',
        '${invoice.valorPagado ?? 0}',
        '${invoice.saldoPendiente}',
        invoice.estado,
        _formatDate(invoice.fechaGeneracion),
        _formatDate(invoice.fechaVencimiento),
      ].map(xls.TextCellValue.new).toList());
    }
    excel.setDefaultSheet('facturacion');
    final bytes = excel.encode();
    if (bytes == null) {
      return;
    }
    await saveConsumptionReportFile(
      bytes: Uint8List.fromList(bytes),
      fileName: 'reporte_facturacion_${_selectedPeriod?.id ?? 'periodo'}.xlsx',
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reporte de facturacion descargado.')),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.periods,
    required this.selectedPeriod,
    required this.invoices,
    required this.statusFilter,
    required this.onPeriodChanged,
    required this.onStatusChanged,
    required this.onExport,
  });

  final List<BillingPeriod> periods;
  final BillingPeriod? selectedPeriod;
  final List<Invoice> invoices;
  final String statusFilter;
  final ValueChanged<BillingPeriod?> onPeriodChanged;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback? onExport;

  @override
  Widget build(BuildContext context) {
    final billed = invoices.fold<int>(
      0,
      (sum, item) => sum + item.currentChargeTotal,
    );
    final totalToPay = invoices.fold<int>(
      0,
      (sum, item) => sum + item.totalAPagar,
    );
    final paid = invoices.fold<int>(0, (sum, item) => sum + (item.valorPagado ?? 0));
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
          Text('Reporte de facturacion', style: Theme.of(context).textTheme.headlineSmall),
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
                  onChanged: onPeriodChanged,
                ),
              ),
              _Metric(label: 'Recibos', value: '${invoices.length}'),
              _Metric(label: 'Facturado', value: _formatCurrency(billed)),
              _Metric(label: 'Total a pagar', value: _formatCurrency(totalToPay)),
              _Metric(label: 'Pagado', value: _formatCurrency(paid)),
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
                label: const Text('Todos'),
                selected: statusFilter == 'all',
                onSelected: (_) => onStatusChanged('all'),
              ),
              ChoiceChip(
                label: const Text('Pagados'),
                selected: statusFilter == 'paid',
                onSelected: (_) => onStatusChanged('paid'),
              ),
              ChoiceChip(
                label: const Text('Pendientes'),
                selected: statusFilter == 'pending',
                onSelected: (_) => onStatusChanged('pending'),
              ),
              ChoiceChip(
                label: const Text('Suspendidos'),
                selected: statusFilter == 'suspended',
                onSelected: (_) => onStatusChanged('suspended'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InvoiceReportCard extends StatelessWidget {
  const _InvoiceReportCard({required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
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
          Text(toDisplayUserName(invoice.nombreUsuario), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text('Codigo: ${invoice.codigoUsuario} - Contador: ${invoice.codigoContador} - Sector: ${toDisplayText(invoice.sector)}'),
          const SizedBox(height: 6),
          Text('Consumo: ${invoice.consumoM3} m3 - Facturado: ${_formatCurrency(invoice.currentChargeTotal)} - Total a pagar: ${_formatCurrency(invoice.totalAPagar)}'),
          const SizedBox(height: 6),
          Text('Pagado: ${_formatCurrency(invoice.valorPagado ?? 0)} - Pendiente: ${_formatCurrency(invoice.saldoPendiente)} - Estado: ${toDisplayText(invoice.estado)}'),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text('$label: $value'));
  }
}

int _consumptionAmount(Invoice invoice) {
  return invoice.lineas
      .where((item) => item.descripcion.toLowerCase().contains('consumo'))
      .fold(0, (sum, item) => sum + item.valorTotal);
}

int _additionalAmount(Invoice invoice) {
  return invoice.lineas
      .where((item) {
        final text = item.descripcion.toLowerCase();
        return !text.contains('cargo fijo') && !text.contains('consumo');
      })
      .fold(0, (sum, item) => sum + item.valorTotal);
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
