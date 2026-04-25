import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/presentation/text_formatters.dart';
import '../../../../theme/app_colors.dart';
import '../../../billing/invoices/data/invoice_firestore_service.dart';
import '../../../billing/invoices/domain/invoice.dart';
import '../../data/consumption_firestore_service.dart';
import '../../domain/consumption_reading.dart';
import 'csv_download_stub.dart' if (dart.library.html) 'csv_download_web.dart';

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
    return Stack(
      children: [
        AbsorbPointer(
          absorbing: _loading,
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
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 980;
                    final readingsPanel = _ReportPanel(
                      title: 'Lecturas consultadas',
                      emptyMessage: 'No hay resultados cargados.',
                      child: _items.isEmpty
                          ? null
                          : ListView.separated(
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
                            ),
                    );
                    final pendingPanel = _ReportPanel(
                      title: 'Informe de cartera pendiente',
                      emptyMessage: 'No hay cartera pendiente con el filtro actual.',
                      child: _pendingInvoices.isEmpty
                          ? null
                          : ListView.separated(
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
                            ),
                    );

                    if (compact) {
                      return Column(
                        children: [
                          Expanded(child: readingsPanel),
                          const SizedBox(height: 16),
                          Expanded(child: pendingPanel),
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: readingsPanel),
                        const SizedBox(width: 16),
                        Expanded(flex: 2, child: pendingPanel),
                      ],
                    );
                  },
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
    );
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final period = _normalize(_periodController.text);
      final customerCode = _normalize(_customerController.text);
      final results = await Future.wait([
        _firestoreService.fetchReadingsReport(
          period: period,
          customerCode: customerCode,
          onlyIrregular: _onlyIrregular,
        ),
        _invoiceService.fetchPendingInvoicesReport(
          period: period,
          customerCode: customerCode,
        ),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _items = results[0] as List<ConsumptionReading>;
        _pendingInvoices = results[1] as List<Invoice>;
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _export() {
    final rows = <List<String>>[
      [
        'periodo',
        'codigo_usuario',
        'nombre_usuario',
        'codigo_contador',
        'lectura_anterior',
        'lectura_actual',
        'consumo_calculado',
        'estado',
        'facturado',
        'pagado',
        'irregularidad',
        'observaciones_operario',
        'observaciones_admin',
      ],
      for (final item in _items)
        [
          item.periodoActual,
          item.codigoUsuario,
          item.nombreUsuario,
          item.codigoContador,
          '${item.lecturaAnterior ?? ''}',
          '${item.lecturaActual}',
          '${item.consumoCalculado ?? ''}',
          item.estado,
          item.facturado ? 'si' : 'no',
          item.pagado ? 'si' : 'no',
          item.irregularidad?.tipo ?? '',
          item.observacionesOperario ?? '',
          item.observacionesAdmin ?? '',
        ],
    ];
    final csv = rows.map(_encodeCsvRow).join('\n');
    final filename = 'consumos_${_normalize(_periodController.text) ?? 'todos'}.csv';
    final downloaded = downloadCsvFile(filename, csv);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          downloaded
              ? 'Reporte descargado.'
              : 'Descarga automatica no disponible en esta plataforma.',
        ),
      ),
    );
  }

  String? _normalize(String value) {
    final text = value.trim();
    return text.isEmpty ? null : text;
  }

  String _encodeCsvRow(List<String> row) {
    return row.map((item) => '"${item.replaceAll('"', '""')}"').join(',');
  }
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
  });

  final String title;
  final String emptyMessage;
  final Widget? child;

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
          Expanded(
            child: child ??
                Center(
                  child: Text(emptyMessage),
                ),
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
