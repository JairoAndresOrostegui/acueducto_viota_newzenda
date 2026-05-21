import 'dart:typed_data';

import 'package:excel/excel.dart' as xls;
import 'package:flutter/material.dart';

import '../../../../core/presentation/text_formatters.dart';
import '../../../../theme/app_colors.dart';
import '../../../billing/periods/data/billing_period_firestore_service.dart';
import '../../../billing/periods/domain/billing_period.dart';
import '../../../consumptions/presentation/pages/consumption_reports_file_exporter_stub.dart'
    if (dart.library.html) '../../../consumptions/presentation/pages/consumption_reports_file_exporter_web.dart';
import '../../../expenses/data/expense_record_firestore_service.dart';
import '../../../expenses/domain/expense_record.dart';

class ExpenseReportsPage extends StatefulWidget {
  const ExpenseReportsPage({
    super.key,
    this.periodService,
    this.expenseService,
  });

  final BillingPeriodFirestoreService? periodService;
  final ExpenseRecordFirestoreService? expenseService;

  @override
  State<ExpenseReportsPage> createState() => _ExpenseReportsPageState();
}

class _ExpenseReportsPageState extends State<ExpenseReportsPage> {
  late final BillingPeriodFirestoreService _periodService =
      widget.periodService ?? BillingPeriodFirestoreService();
  late final ExpenseRecordFirestoreService _expenseService =
      widget.expenseService ?? ExpenseRecordFirestoreService();

  bool _loading = true;
  bool _hasGenerated = false;
  String? _error;
  BillingPeriod? _selectedPeriod;
  List<BillingPeriod> _periods = const [];
  List<ExpenseRecord> _expenses = const [];

  int get _totalAmount {
    return _expenses.fold(0, (sum, item) => sum + item.valor);
  }

  @override
  void initState() {
    super.initState();
    _loadPeriods();
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

  Future<void> _generate() async {
    final period = _selectedPeriod;
    if (period == null) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final expenses = await _expenseService.fetchByPeriod(period.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _expenses = expenses;
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(
          periods: _periods,
          selectedPeriod: _selectedPeriod,
          expenses: _hasGenerated ? _expenses : const [],
          totalAmount: _hasGenerated ? _totalAmount : 0,
          onPeriodChanged: (period) {
            setState(() {
              _selectedPeriod = period;
              _expenses = const [];
              _hasGenerated = false;
            });
          },
          onGenerate: _selectedPeriod == null ? null : _generate,
          onExport: !_hasGenerated || _expenses.isEmpty ? null : _export,
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
                        ? 'Selecciona el periodo y genera el reporte.'
                        : _expenses.isEmpty
                            ? 'No hay gastos para este periodo.'
                            : 'Reporte generado. Puedes exportar el Excel.',
                    textAlign: TextAlign.center,
                  ),
                ),
        ),
      ],
    );
  }

  Future<void> _export() async {
    final period = _selectedPeriod;
    if (period == null) {
      return;
    }
    final excel = xls.Excel.createExcel();
    final sheet = excel['gastos'];
    sheet.appendRow([
      'periodo',
      'concepto',
      'valor',
      'fecha_gasto',
      'pagado_a_nombre',
      'pagado_a_identificacion',
      'registrado_por',
      'fecha_registro',
      'actualizado_por',
      'fecha_actualizacion',
    ].map(xls.TextCellValue.new).toList());

    var total = 0;
    for (final item in _expenses) {
      total += item.valor;
      sheet.appendRow([
        xls.TextCellValue(item.periodoId),
        xls.TextCellValue(item.conceptoNombre),
        xls.IntCellValue(item.valor),
        xls.TextCellValue(_formatDate(item.fechaGasto)),
        xls.TextCellValue(item.pagadoANombre),
        xls.TextCellValue(item.pagadoAIdentificacion),
        xls.TextCellValue(item.registradoPorNombre),
        xls.TextCellValue(_formatDate(item.fechaRegistro)),
        xls.TextCellValue(item.actualizadoPorNombre ?? ''),
        xls.TextCellValue(
          item.fechaActualizacion == null
              ? ''
              : _formatDate(item.fechaActualizacion!),
        ),
      ]);
    }
    sheet.appendRow([
      xls.TextCellValue('TOTAL'),
      xls.TextCellValue(''),
      xls.IntCellValue(total),
      xls.TextCellValue(''),
      xls.TextCellValue(''),
      xls.TextCellValue(''),
      xls.TextCellValue(''),
      xls.TextCellValue(''),
      xls.TextCellValue(''),
      xls.TextCellValue(''),
    ]);

    excel.setDefaultSheet('gastos');
    final bytes = excel.encode();
    if (bytes == null) {
      return;
    }
    await saveConsumptionReportFile(
      bytes: Uint8List.fromList(bytes),
      fileName: 'reporte_gastos_${period.id}.xlsx',
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reporte de gastos descargado.')),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.periods,
    required this.selectedPeriod,
    required this.expenses,
    required this.totalAmount,
    required this.onPeriodChanged,
    required this.onGenerate,
    required this.onExport,
  });

  final List<BillingPeriod> periods;
  final BillingPeriod? selectedPeriod;
  final List<ExpenseRecord> expenses;
  final int totalAmount;
  final ValueChanged<BillingPeriod?> onPeriodChanged;
  final VoidCallback? onGenerate;
  final VoidCallback? onExport;

  @override
  Widget build(BuildContext context) {
    final concepts = expenses.map((item) => item.conceptoId).toSet().length;
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
          Text(
            'Reporte de gastos',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 280,
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
              Chip(label: Text('Registros: ${expenses.length}')),
              Chip(label: Text('Conceptos: $concepts')),
              Chip(label: Text('Total: ${_formatCurrency(totalAmount)}')),
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
        ],
      ),
    );
  }
}

String _periodLabel(BillingPeriod period) {
  return '${period.clave} - ${toDisplayText(period.nombre)}${period.vigente ? ' - Vigente' : ''}';
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
