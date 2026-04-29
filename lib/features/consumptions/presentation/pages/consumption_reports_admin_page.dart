import 'dart:typed_data';

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:excel/excel.dart' as xls;

import '../../../../core/presentation/text_formatters.dart';
import '../../../../theme/app_colors.dart';
import '../../../billing/invoices/data/invoice_firestore_service.dart';
import '../../../billing/invoices/domain/invoice.dart';
import '../../data/consumption_firestore_service.dart';
import '../../domain/consumption_reading.dart';
import 'consumption_reports_file_exporter_stub.dart'
    if (dart.library.html) 'consumption_reports_file_exporter_web.dart';

class ConsumptionReportsAdminPage extends StatefulWidget {
  const ConsumptionReportsAdminPage({
    super.key,
    this.firestoreService,
    this.invoiceService,
  });

  final ConsumptionFirestoreService? firestoreService;
  final InvoiceFirestoreService? invoiceService;

  @override
  State<ConsumptionReportsAdminPage> createState() =>
      _ConsumptionReportsAdminPageState();
}

class _ConsumptionReportsAdminPageState
    extends State<ConsumptionReportsAdminPage> {
  late final ConsumptionFirestoreService _firestoreService =
      widget.firestoreService ?? ConsumptionFirestoreService();
  late final InvoiceFirestoreService _invoiceService =
      widget.invoiceService ?? InvoiceFirestoreService();

  final TextEditingController _periodController = TextEditingController();
  final TextEditingController _customerController = TextEditingController();

  bool _loading = false;
  bool _onlyIrregular = false;
  List<ConsumptionReading> _items = const [];
  List<Invoice> _pendingInvoices = const [];
  Map<_InvoiceKey, Invoice> _invoicesByReading = const {};

  int get _pendingAmount {
    return _pendingInvoices.fold<int>(
      0,
      (sum, invoice) => sum + math.max(invoice.total - (invoice.valorPagado ?? 0), 0),
    );
  }

  @override
  void dispose() {
    _periodController.dispose();
    _customerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final highContrastTheme = baseTheme.copyWith(
      textTheme: baseTheme.textTheme.apply(
        bodyColor: Colors.black,
        displayColor: Colors.black,
      ),
      inputDecorationTheme: baseTheme.inputDecorationTheme.copyWith(
        labelStyle: const TextStyle(color: Colors.black),
        floatingLabelStyle: const TextStyle(color: Colors.black),
        hintStyle: const TextStyle(color: Colors.black87),
      ),
    );
    final compact = MediaQuery.sizeOf(context).width < 980;
    final readingsList = _items.isEmpty
        ? null
        : ListView.separated(
            shrinkWrap: compact,
            physics: compact
                ? const NeverScrollableScrollPhysics()
                : const AlwaysScrollableScrollPhysics(),
            itemCount: _items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = _items[index];
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${item.periodoActual} - ${toDisplayUserName(item.nombreUsuario)}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Usuario: ${item.codigoUsuario} - Contador: ${item.codigoContador}',
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Lectura anterior: ${item.lecturaAnterior ?? '-'} - Lectura actual: ${item.lecturaActual} - Consumo: ${item.consumoCalculado ?? '-'}',
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Estado: ${item.estado} - Facturado: ${item.facturado ? 'si' : 'no'} - Pagado: ${item.pagado ? 'si' : 'no'}',
                    ),
                    if (item.irregularidad != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Irregularidad: ${item.irregularidad!.tipo} - ${item.irregularidad!.descripcion}',
                      ),
                    ],
                  ],
                ),
              );
            },
          );
    final pendingList = _pendingInvoices.isEmpty
        ? null
        : ListView.separated(
            shrinkWrap: compact,
            physics: compact
                ? const NeverScrollableScrollPhysics()
                : const AlwaysScrollableScrollPhysics(),
            itemCount: _pendingInvoices.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final invoice = _pendingInvoices[index];
              final paid = invoice.valorPagado ?? 0;
              final pending = math.max(invoice.total - paid, 0);
              return Container(
                padding: const EdgeInsets.all(16),
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
                    Text('Usuario: ${invoice.codigoUsuario}'),
                    const SizedBox(height: 4),
                    Text('Contador: ${invoice.codigoContador}'),
                    const SizedBox(height: 4),
                    Text('Periodo: ${invoice.periodo}'),
                    const SizedBox(height: 4),
                    Text('Estado: ${toDisplayText(invoice.estado)}'),
                    const SizedBox(height: 4),
                    Text('Vencimiento: ${_formatDate(invoice.fechaVencimiento)}'),
                    const SizedBox(height: 8),
                    Text('Total facturado: ${_formatCurrency(invoice.total)}'),
                    const SizedBox(height: 4),
                    Text('Valor registrado: ${_formatCurrency(paid)}'),
                    const SizedBox(height: 4),
                    Text(
                      'Saldo pendiente: ${_formatCurrency(pending)}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Colors.orange.shade900,
                          ),
                    ),
                  ],
                ),
              );
            },
          );
    final readingsPanel = _ReportPanel(
      title: 'Lecturas consultadas',
      emptyMessage: 'No hay resultados cargados.',
      expandChild: !compact,
      child: readingsList,
    );
    final pendingPanel = _ReportPanel(
      title: 'Informe de cartera pendiente',
      emptyMessage: 'No hay cartera pendiente con el filtro actual.',
      expandChild: !compact,
      child: pendingList,
    );

    return Theme(
      data: highContrastTheme,
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: Colors.black),
        child: Stack(
        children: [
          AbsorbPointer(
            absorbing: _loading,
            child: compact
              ? SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Consultas y reportes',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Consulta consumos por periodo o usuario y revisa la cartera pendiente del mismo filtro.',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: 220,
                            child: TextField(
                              controller: _periodController,
                              decoration: const InputDecoration(
                                labelText: 'Periodo (YYYY-MM) o vacio',
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 220,
                            child: TextField(
                              controller: _customerController,
                              decoration: const InputDecoration(
                                labelText: 'Codigo usuario o vacio',
                              ),
                            ),
                          ),
                          FilterChip(
                            label: const Text('Solo irregularidades'),
                            labelStyle: const TextStyle(color: Colors.black),
                            selected: _onlyIrregular,
                            onSelected: (value) {
                              setState(() => _onlyIrregular = value);
                            },
                          ),
                          ElevatedButton.icon(
                            onPressed: _load,
                            icon: const Icon(Icons.search_rounded),
                            label: const Text('Consultar'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _items.isEmpty ? null : _export,
                            icon: const Icon(Icons.download_rounded),
                            label: const Text('Exportar CSV'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _MetricCard(
                            label: 'Lecturas',
                            value: '${_items.length}',
                          ),
                          _MetricCard(
                            label: 'Recibos pendientes',
                            value: '${_pendingInvoices.length}',
                          ),
                          _MetricCard(
                            label: 'Cartera pendiente',
                            value: _formatCurrency(_pendingAmount),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      readingsPanel,
                      const SizedBox(height: 16),
                      pendingPanel,
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Consultas y reportes',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Consulta consumos por periodo o usuario y revisa la cartera pendiente del mismo filtro.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: 220,
                          child: TextField(
                            controller: _periodController,
                            decoration: const InputDecoration(
                              labelText: 'Periodo (YYYY-MM) o vacio',
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 220,
                          child: TextField(
                            controller: _customerController,
                            decoration: const InputDecoration(
                              labelText: 'Codigo usuario o vacio',
                            ),
                          ),
                        ),
                        FilterChip(
                          label: const Text('Solo irregularidades'),
                          labelStyle: const TextStyle(color: Colors.black),
                          selected: _onlyIrregular,
                          onSelected: (value) {
                            setState(() => _onlyIrregular = value);
                          },
                        ),
                        ElevatedButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.search_rounded),
                          label: const Text('Consultar'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _items.isEmpty ? null : _export,
                          icon: const Icon(Icons.download_rounded),
                          label: const Text('Exportar CSV'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _MetricCard(
                          label: 'Lecturas',
                          value: '${_items.length}',
                        ),
                        _MetricCard(
                          label: 'Recibos pendientes',
                          value: '${_pendingInvoices.length}',
                        ),
                        _MetricCard(
                          label: 'Cartera pendiente',
                          value: _formatCurrency(_pendingAmount),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: readingsPanel),
                          const SizedBox(width: 16),
                          Expanded(flex: 2, child: pendingPanel),
                        ],
                      ),
                    ),
                  ],
                ),
          ),
          if (_loading)
            Positioned.fill(
              child: ColoredBox(
                color: AppColors.textPrimary.withValues(alpha: 0.18),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
        ),
      ),
    );
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final period = _normalize(_periodController.text);
      final customerCode = _normalize(_customerController.text);
      final readingsFuture = _firestoreService.fetchReadingsReport(
        period: period,
        customerCode: customerCode,
        onlyIrregular: _onlyIrregular,
      );
      final pendingInvoicesFuture = _invoiceService.fetchPendingInvoicesReport(
        period: period,
        customerCode: customerCode,
      );
      final readings = await readingsFuture;
      final invoicesByReading = await _fetchInvoicesByReading(readings);
      final pendingInvoices = await pendingInvoicesFuture;
      if (!mounted) {
        return;
      }
      setState(() {
        _items = readings;
        _invoicesByReading = invoicesByReading;
        _pendingInvoices = pendingInvoices;
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _export() async {
    final messenger = ScaffoldMessenger.of(context);
    final excel = xls.Excel.createExcel();
    final sheet = excel['reporte'];
    sheet.appendRow([
      xls.TextCellValue('periodo'),
      xls.TextCellValue('codigo_usuario'),
      xls.TextCellValue('nombre_usuario'),
      xls.TextCellValue('codigo_contador'),
      xls.TextCellValue('lectura_anterior'),
      xls.TextCellValue('lectura_actual'),
      xls.TextCellValue('consumo_calculado'),
      xls.TextCellValue('saldo_anterior'),
      xls.TextCellValue('valor_total_a_pagar'),
      xls.TextCellValue('valor_pagado'),
      xls.TextCellValue('estado'),
      xls.TextCellValue('facturado'),
      xls.TextCellValue('pagado'),
      xls.TextCellValue('irregularidad'),
      xls.TextCellValue('observaciones_operario'),
      xls.TextCellValue('observaciones_admin'),
    ]);
    for (final item in _items) {
      final row = _exportRowForReading(item);
      sheet.appendRow(
        row.map((value) => xls.TextCellValue(value)).toList(),
      );
    }
    excel.setDefaultSheet('reporte');
    final bytes = excel.encode();
    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No fue posible generar el Excel.')),
      );
      return;
    }
    final filename = 'consumos_${_normalize(_periodController.text) ?? 'todos'}.xlsx';
    await saveConsumptionReportFile(
      bytes: Uint8List.fromList(bytes),
      fileName: filename,
    );
    messenger.showSnackBar(
      const SnackBar(content: Text('Reporte Excel descargado.')),
    );
  }

  String? _normalize(String value) {
    final text = value.trim();
    return text.isEmpty ? null : text;
  }

  List<String> _exportRowForReading(ConsumptionReading item) {
    final invoice = _invoicesByReading[_InvoiceKey.fromReading(item)];
    return [
      item.periodoActual,
      item.codigoUsuario,
      item.nombreUsuario,
      item.codigoContador,
      '${item.lecturaAnterior ?? ''}',
      '${item.lecturaActual}',
      '${item.consumoCalculado ?? ''}',
      invoice == null ? '' : '${invoice.saldoAnterior}',
      invoice == null ? '' : '${_invoiceTotalToPay(invoice)}',
      '${invoice?.valorPagado ?? 0}',
      item.estado,
      item.facturado ? 'si' : 'no',
      item.pagado ? 'si' : 'no',
      item.irregularidad?.tipo ?? '',
      item.observacionesOperario ?? '',
      item.observacionesAdmin ?? '',
    ];
  }

  Future<Map<_InvoiceKey, Invoice>> _fetchInvoicesByReading(
    List<ConsumptionReading> readings,
  ) async {
    final periods = readings.map((item) => item.periodoActual).toSet().toList();
    final invoicesByReading = <_InvoiceKey, Invoice>{};
    for (final period in periods) {
      final invoices = await _invoiceService.fetchInvoicesForPeriod(period);
      for (final invoice in invoices) {
        invoicesByReading[_InvoiceKey.fromInvoice(invoice)] = invoice;
      }
    }
    return invoicesByReading;
  }
}

int _invoiceTotalToPay(Invoice invoice) {
  return invoice.total + invoice.saldoAnterior + invoice.reconexion;
}

@immutable
class _InvoiceKey {
  const _InvoiceKey(this.period, this.meterCode);

  factory _InvoiceKey.fromReading(ConsumptionReading reading) {
    return _InvoiceKey(reading.periodoActual, reading.codigoContador);
  }

  factory _InvoiceKey.fromInvoice(Invoice invoice) {
    return _InvoiceKey(invoice.periodo, invoice.codigoContador);
  }

  final String period;
  final String meterCode;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _InvoiceKey &&
            other.period == period &&
            other.meterCode == meterCode;
  }

  @override
  int get hashCode => Object.hash(period, meterCode);
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 210,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Text(value, style: Theme.of(context).textTheme.headlineSmall),
        ],
      ),
    );
  }
}

class _ReportPanel extends StatelessWidget {
  const _ReportPanel({
    required this.title,
    required this.emptyMessage,
    required this.child,
    this.expandChild = true,
  });

  final String title;
  final String emptyMessage;
  final Widget? child;
  final bool expandChild;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFA),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (expandChild)
            Expanded(
              child: child ??
                  Center(
                    child: Text(emptyMessage),
                  ),
            )
          else
            child ??
                Center(
                  child: Text(emptyMessage),
                ),
        ],
      ),
    );
  }
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
