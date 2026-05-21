import 'dart:typed_data';

import 'package:excel/excel.dart' as xls;
import 'package:flutter/material.dart';

import '../../../../core/presentation/text_formatters.dart';
import '../../../../theme/app_colors.dart';
import '../../../billing/periods/data/billing_period_firestore_service.dart';
import '../../../billing/periods/domain/billing_period.dart';
import '../../../billing/values/data/billing_value_config_firestore_service.dart';
import '../../../billing/values/domain/billing_value_config.dart';
import '../../../consumptions/presentation/pages/consumption_reports_file_exporter_stub.dart'
    if (dart.library.html) '../../../consumptions/presentation/pages/consumption_reports_file_exporter_web.dart';
import '../../../users/data/user_firestore_service.dart';
import '../../../users/domain/app_user.dart';

class ExtraordinaryReportsPage extends StatefulWidget {
  const ExtraordinaryReportsPage({
    super.key,
    this.periodService,
    this.valueService,
    this.userService,
  });

  final BillingPeriodFirestoreService? periodService;
  final BillingValueConfigFirestoreService? valueService;
  final UserFirestoreService? userService;

  @override
  State<ExtraordinaryReportsPage> createState() =>
      _ExtraordinaryReportsPageState();
}

class _ExtraordinaryReportsPageState extends State<ExtraordinaryReportsPage> {
  late final BillingPeriodFirestoreService _periodService =
      widget.periodService ?? BillingPeriodFirestoreService();
  late final BillingValueConfigFirestoreService _valueService =
      widget.valueService ?? BillingValueConfigFirestoreService();
  late final UserFirestoreService _userService =
      widget.userService ?? UserFirestoreService();

  bool _loading = true;
  bool _hasGenerated = false;
  String? _error;
  BillingPeriod? _selectedPeriod;
  List<BillingPeriod> _periods = const [];
  List<_ExtraordinaryReportRow> _rows = const [];

  int get _totalAmount {
    return _rows.fold(0, (sum, item) => sum + item.value.valor);
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
      final results = await Future.wait([
        _valueService.fetchActiveItem(),
        _userService.fetchActiveClients(limit: 5000),
      ]);
      final activeValues = results[0] as BillingValueConfig?;
      final clients = results[1] as List<AppUser>;
      final clientByCode = _buildClientIndex(clients);
      final rows = (activeValues?.valoresAdicionales ?? const [])
          .where((item) => item.periodoId == period.id)
          .map(
            (item) => _ExtraordinaryReportRow(
              value: item,
              clientReference:
                  clientByCode[_normalizeUserCode(item.codigoUsuario ?? '')],
            ),
          )
          .toList()
        ..sort((a, b) {
          final conceptCompare = a.value.concepto.compareTo(b.value.concepto);
          if (conceptCompare != 0) {
            return conceptCompare;
          }
          return (a.value.codigoUsuario ?? '').compareTo(
            b.value.codigoUsuario ?? '',
          );
        });
      if (!mounted) {
        return;
      }
      setState(() {
        _rows = rows;
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
          rows: _hasGenerated ? _rows : const [],
          totalAmount: _hasGenerated ? _totalAmount : 0,
          onPeriodChanged: (period) {
            setState(() {
              _selectedPeriod = period;
              _rows = const [];
              _hasGenerated = false;
            });
          },
          onGenerate: _selectedPeriod == null ? null : _generate,
          onExport: !_hasGenerated || _rows.isEmpty ? null : _export,
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
                        : _rows.isEmpty
                            ? 'No hay extraordinarios para este periodo.'
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
    final sheet = excel['extraordinarios'];
    sheet.appendRow([
      'periodo',
      'codigo_usuario',
      'nombre_usuario',
      'identificacion_usuario',
      'sector',
      'contador',
      'alcance',
      'concepto',
      'valor',
    ].map(xls.TextCellValue.new).toList());

    var total = 0;
    for (final row in _rows) {
      final value = row.value;
      final ref = row.clientReference;
      total += value.valor;
      sheet.appendRow([
        xls.TextCellValue(value.periodoId),
        xls.TextCellValue(value.codigoUsuario ?? ''),
        xls.TextCellValue(ref?.client.nombre ?? ''),
        xls.TextCellValue(ref?.client.numeroDocumento ?? ''),
        xls.TextCellValue(ref?.code.sector ?? ''),
        xls.TextCellValue(ref?.code.numeroContador ?? ''),
        xls.TextCellValue(value.isMassive ? 'masivo' : 'individual'),
        xls.TextCellValue(value.concepto),
        xls.IntCellValue(value.valor),
      ]);
    }
    sheet.appendRow([
      xls.TextCellValue('TOTAL'),
      xls.TextCellValue(''),
      xls.TextCellValue(''),
      xls.TextCellValue(''),
      xls.TextCellValue(''),
      xls.TextCellValue(''),
      xls.TextCellValue(''),
      xls.TextCellValue(''),
      xls.IntCellValue(total),
    ]);

    excel.setDefaultSheet('extraordinarios');
    final bytes = excel.encode();
    if (bytes == null) {
      return;
    }
    await saveConsumptionReportFile(
      bytes: Uint8List.fromList(bytes),
      fileName: 'reporte_extraordinarios_${period.id}.xlsx',
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reporte de extraordinarios descargado.')),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.periods,
    required this.selectedPeriod,
    required this.rows,
    required this.totalAmount,
    required this.onPeriodChanged,
    required this.onGenerate,
    required this.onExport,
  });

  final List<BillingPeriod> periods;
  final BillingPeriod? selectedPeriod;
  final List<_ExtraordinaryReportRow> rows;
  final int totalAmount;
  final ValueChanged<BillingPeriod?> onPeriodChanged;
  final VoidCallback? onGenerate;
  final VoidCallback? onExport;

  @override
  Widget build(BuildContext context) {
    final massive = rows.where((item) => item.value.isMassive).length;
    final individual = rows.length - massive;
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
            'Reporte de extraordinarios',
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
              Chip(label: Text('Registros: ${rows.length}')),
              Chip(label: Text('Masivos: $massive')),
              Chip(label: Text('Individuales: $individual')),
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

class _ExtraordinaryReportRow {
  const _ExtraordinaryReportRow({
    required this.value,
    required this.clientReference,
  });

  final AdditionalBillingValue value;
  final _ClientCodeReference? clientReference;
}

class _ClientCodeReference {
  const _ClientCodeReference({required this.client, required this.code});

  final AppUser client;
  final ClientUserCode code;
}

Map<String, _ClientCodeReference> _buildClientIndex(List<AppUser> clients) {
  return {
    for (final client in clients)
      for (final code in client.codigosUsuario)
        if (_normalizeUserCode(code.codigoUsuario).isNotEmpty)
          _normalizeUserCode(code.codigoUsuario): _ClientCodeReference(
            client: client,
            code: code,
          ),
  };
}

String _normalizeUserCode(String value) {
  return value.trim().toUpperCase();
}

String _periodLabel(BillingPeriod period) {
  return '${period.clave} - ${toDisplayText(period.nombre)}${period.vigente ? ' - Vigente' : ''}';
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
