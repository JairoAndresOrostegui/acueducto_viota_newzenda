import 'dart:typed_data';

import 'package:excel/excel.dart' as xls;
import 'package:flutter/material.dart';

import '../../../../core/presentation/text_formatters.dart';
import '../../../../theme/app_colors.dart';
import '../../../billing/periods/data/billing_period_firestore_service.dart';
import '../../../billing/periods/domain/billing_period.dart';
import '../../../consumptions/data/consumption_firestore_service.dart';
import '../../../consumptions/domain/consumption_reading.dart';
import '../../../consumptions/presentation/pages/consumption_reports_file_exporter_stub.dart'
    if (dart.library.html) '../../../consumptions/presentation/pages/consumption_reports_file_exporter_web.dart';

class ConsumptionReportsPlaceholderPage extends StatefulWidget {
  const ConsumptionReportsPlaceholderPage({
    super.key,
    this.periodService,
    this.consumptionService,
  });

  final BillingPeriodFirestoreService? periodService;
  final ConsumptionFirestoreService? consumptionService;

  @override
  State<ConsumptionReportsPlaceholderPage> createState() =>
      _ConsumptionReportsPlaceholderPageState();
}

class _ConsumptionReportsPlaceholderPageState
    extends State<ConsumptionReportsPlaceholderPage> {
  late final BillingPeriodFirestoreService _periodService =
      widget.periodService ?? BillingPeriodFirestoreService();
  late final ConsumptionFirestoreService _consumptionService =
      widget.consumptionService ?? ConsumptionFirestoreService();

  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  bool _hasGenerated = false;
  bool _onlyIrregular = false;
  String? _error;
  String _query = '';
  String _statusFilter = 'all';
  BillingPeriod? _selectedPeriod;
  List<BillingPeriod> _periods = const [];
  List<ConsumptionReading> _readings = const [];

  int get _totalConsumption => _readings.fold(
        0,
        (sum, item) => sum + (item.consumoCalculado ?? 0),
      );

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

  Future<void> _loadReadings(BillingPeriod period) async {
    if (!mounted) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _selectedPeriod = period;
    });
    try {
      final readings = await _consumptionService.fetchReadingsForPeriod(
        period.id,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _readings = readings;
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
    final rows = _filteredReadings();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(
          periods: _periods,
          selectedPeriod: _selectedPeriod,
          readings: _readings,
          totalConsumption: _totalConsumption,
          onlyIrregular: _onlyIrregular,
          statusFilter: _statusFilter,
          onPeriodChanged: (period) {
            setState(() {
              _selectedPeriod = period;
              _readings = const [];
              _hasGenerated = false;
            });
          },
          onIrregularChanged: (value) => setState(() => _onlyIrregular = value),
          onStatusChanged: (value) => setState(() => _statusFilter = value),
          onGenerate: _selectedPeriod == null
              ? null
              : () => _loadReadings(_selectedPeriod!),
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
                        ? 'No hay consumos que coincidan con el filtro.'
                        : 'Reporte generado. Puedes exportar el Excel.',
                    textAlign: TextAlign.center,
                  ),
                ),
        ),
      ],
    );
  }

  List<ConsumptionReading> _filteredReadings() {
    final query = _query.trim().toLowerCase();
    return _readings.where((reading) {
      if (_onlyIrregular && !reading.hasIrregularity) {
        return false;
      }
      if (_statusFilter == 'billed' && !reading.facturado) {
        return false;
      }
      if (_statusFilter == 'unbilled' && reading.facturado) {
        return false;
      }
      if (_statusFilter == 'paid' && !reading.pagado) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      return [
        reading.nombreUsuario,
        reading.codigoUsuario,
        reading.codigoContador,
        reading.sector,
        reading.estado,
      ].join(' ').toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _export(List<ConsumptionReading> readings) async {
    final excel = xls.Excel.createExcel();
    final sheet = excel['consumos'];
    sheet.appendRow([
      'periodo',
      'codigo_usuario',
      'nombre_usuario',
      'sector',
      'contador',
      'lectura_anterior',
      'lectura_actual',
      'consumo_m3',
      'estado_consumo',
      'facturado',
      'pagado',
      'irregularidad_tipo',
      'irregularidad_descripcion',
      'observaciones_operario',
      'observaciones_admin',
    ].map(xls.TextCellValue.new).toList());
    var totalLecturaAnterior = 0;
    var totalLecturaActual = 0;
    var totalConsumoM3 = 0;
    for (final reading in readings) {
      final previousReading = reading.lecturaAnterior;
      final consumption = reading.consumoCalculado;
      if (previousReading != null) {
        totalLecturaAnterior += previousReading;
      }
      totalLecturaActual += reading.lecturaActual;
      if (consumption != null) {
        totalConsumoM3 += consumption;
      }
      sheet.appendRow([
        xls.TextCellValue(reading.periodoActual),
        xls.TextCellValue(reading.codigoUsuario),
        xls.TextCellValue(reading.nombreUsuario),
        xls.TextCellValue(reading.sector),
        xls.TextCellValue(reading.codigoContador),
        previousReading == null
            ? xls.TextCellValue('')
            : xls.IntCellValue(previousReading),
        xls.IntCellValue(reading.lecturaActual),
        consumption == null
            ? xls.TextCellValue('')
            : xls.IntCellValue(consumption),
        xls.TextCellValue(reading.estado),
        xls.TextCellValue(reading.facturado ? 'si' : 'no'),
        xls.TextCellValue(reading.pagado ? 'si' : 'no'),
        xls.TextCellValue(reading.irregularidad?.tipo ?? ''),
        xls.TextCellValue(reading.irregularidad?.descripcion ?? ''),
        xls.TextCellValue(reading.observacionesOperario ?? ''),
        xls.TextCellValue(reading.observacionesAdmin ?? ''),
      ]);
    }
    sheet.appendRow([
      xls.TextCellValue('TOTAL'),
      xls.TextCellValue(''),
      xls.TextCellValue(''),
      xls.TextCellValue(''),
      xls.TextCellValue(''),
      xls.IntCellValue(totalLecturaAnterior),
      xls.IntCellValue(totalLecturaActual),
      xls.IntCellValue(totalConsumoM3),
      xls.TextCellValue(''),
      xls.TextCellValue(''),
      xls.TextCellValue(''),
      xls.TextCellValue(''),
      xls.TextCellValue(''),
      xls.TextCellValue(''),
      xls.TextCellValue(''),
    ]);
    excel.setDefaultSheet('consumos');
    final bytes = excel.encode();
    if (bytes == null) {
      return;
    }
    await saveConsumptionReportFile(
      bytes: Uint8List.fromList(bytes),
      fileName: 'reporte_consumos_${_selectedPeriod?.id ?? 'periodo'}.xlsx',
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reporte de consumos descargado.')),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.periods,
    required this.selectedPeriod,
    required this.readings,
    required this.totalConsumption,
    required this.onlyIrregular,
    required this.statusFilter,
    required this.onPeriodChanged,
    required this.onIrregularChanged,
    required this.onStatusChanged,
    required this.onGenerate,
    required this.onExport,
  });

  final List<BillingPeriod> periods;
  final BillingPeriod? selectedPeriod;
  final List<ConsumptionReading> readings;
  final int totalConsumption;
  final bool onlyIrregular;
  final String statusFilter;
  final ValueChanged<BillingPeriod?> onPeriodChanged;
  final ValueChanged<bool> onIrregularChanged;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback? onGenerate;
  final VoidCallback? onExport;

  @override
  Widget build(BuildContext context) {
    final irregular = readings.where((item) => item.hasIrregularity).length;
    final billed = readings.where((item) => item.facturado).length;
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
          Text('Reporte de consumos', style: Theme.of(context).textTheme.headlineSmall),
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
              Chip(label: Text('Lecturas: ${readings.length}')),
              Chip(label: Text('Consumo m3: $totalConsumption')),
              Chip(label: Text('Irregularidades: $irregular')),
              Chip(label: Text('Facturados: $billed')),
              FilterChip(
                label: const Text('Solo irregularidades'),
                selected: onlyIrregular,
                onSelected: onIrregularChanged,
              ),
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
                label: const Text('Todos'),
                selected: statusFilter == 'all',
                onSelected: (_) => onStatusChanged('all'),
              ),
              ChoiceChip(
                label: const Text('Facturados'),
                selected: statusFilter == 'billed',
                onSelected: (_) => onStatusChanged('billed'),
              ),
              ChoiceChip(
                label: const Text('Sin facturar'),
                selected: statusFilter == 'unbilled',
                onSelected: (_) => onStatusChanged('unbilled'),
              ),
              ChoiceChip(
                label: const Text('Pagados'),
                selected: statusFilter == 'paid',
                onSelected: (_) => onStatusChanged('paid'),
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
