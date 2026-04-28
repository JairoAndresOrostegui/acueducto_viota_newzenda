import 'dart:typed_data';
import 'dart:ui';

import 'package:excel/excel.dart' as xls;
import 'package:flutter/material.dart';

import '../../../../core/platform/excel_file_picker_stub.dart'
    if (dart.library.html) '../../../../core/platform/excel_file_picker_web.dart';
import '../../../../theme/app_colors.dart';
import '../../data/consumption_import_functions_service.dart';
import 'consumption_import_file_exporter_stub.dart'
    if (dart.library.html) 'consumption_import_file_exporter_web.dart';

class ConsumptionImportPage extends StatefulWidget {
  const ConsumptionImportPage({
    super.key,
    this.service,
  });

  final ConsumptionImportFunctionsService? service;

  @override
  State<ConsumptionImportPage> createState() => _ConsumptionImportPageState();
}

class _ConsumptionImportPageState extends State<ConsumptionImportPage> {
  late final ConsumptionImportFunctionsService _service =
      widget.service ?? ConsumptionImportFunctionsService();

  bool _isBusy = false;
  String? _message;
  String? _period;
  List<Map<String, String>> _rows = const [];
  ConsumptionImportSummary? _summary;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Importar consumos',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'La plantilla usa dos columnas: codigousuario y una columna cuyo encabezado es el periodo real, por ejemplo 2026-01. Los valores de esa segunda columna son la lectura actual.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: _isBusy ? null : _downloadTemplate,
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Descargar plantilla Excel'),
                ),
                OutlinedButton.icon(
                  onPressed: _isBusy ? null : _pickFile,
                  icon: const Icon(Icons.upload_file_rounded),
                  label: const Text('Seleccionar archivo'),
                ),
                FilledButton.icon(
                  onPressed: _isBusy || _rows.isEmpty ? null : _importRows,
                  icon: const Icon(Icons.cloud_upload_rounded),
                  label: const Text('Importar consumos'),
                ),
                if ((_summary?.ignoredRows.isNotEmpty ?? false))
                  OutlinedButton.icon(
                    onPressed: _isBusy ? null : _downloadIgnoredRows,
                    icon: const Icon(Icons.file_download_outlined),
                    label: const Text('Descargar ignorados'),
                  ),
              ],
            ),
            if (_message case final message?) ...[
              const SizedBox(height: 12),
              Text(message, style: Theme.of(context).textTheme.bodyMedium),
            ],
            if (_summary != null) ...[
              const SizedBox(height: 12),
              _ImportSummary(summary: _summary!),
            ],
            const SizedBox(height: 16),
            Expanded(
              child: _rows.isEmpty
                  ? const _EmptyImportState()
                  : _PreviewTable(period: _period ?? '', rows: _rows),
            ),
          ],
        ),
        if (_isBusy)
          Positioned.fill(
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: ColoredBox(
                  color: AppColors.textPrimary.withValues(alpha: 0.15),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 14),
                        Text('Procesando consumos...'),
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

  Future<void> _downloadTemplate() async {
    final excel = xls.Excel.createExcel();
    final sheet = excel['consumos'];
    sheet.appendRow([
      xls.TextCellValue('codigousuario'),
      xls.TextCellValue('2026-01'),
    ]);
    excel.setDefaultSheet('consumos');
    final bytes = excel.encode();
    if (bytes == null) {
      setState(() => _message = 'No fue posible generar la plantilla.');
      return;
    }
    await saveConsumptionImportFile(
      bytes: Uint8List.fromList(bytes),
      fileName: 'plantilla_import_consumos.xlsx',
    );
  }

  Future<void> _pickFile() async {
    setState(() {
      _isBusy = true;
      _message = null;
      _summary = null;
    });
    try {
      final bytes = await pickExcelFileBytes();
      if (bytes == null) {
        return;
      }
      final parsed = _parseWorkbook(bytes);
      setState(() {
        _period = parsed.period;
        _rows = parsed.rows;
        _message =
            'Archivo cargado para ${parsed.period}: ${parsed.rows.length} lecturas listas.';
      });
    } catch (error) {
      setState(() => _message = 'No fue posible leer el archivo: $error');
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  _ParsedConsumptionImport _parseWorkbook(Uint8List bytes) {
    final workbook = xls.Excel.decodeBytes(bytes);
    if (workbook.tables.isEmpty) {
      return const _ParsedConsumptionImport(period: '', rows: []);
    }
    final table = workbook.tables.values.first;
    if (table.rows.isEmpty) {
      return const _ParsedConsumptionImport(period: '', rows: []);
    }
    final headers = table.rows.first
        .map((cell) => _cellValue(cell).trim().toLowerCase())
        .toList();
    final codeIndex = headers.indexOf('codigousuario');
    if (codeIndex < 0) {
      throw Exception('Falta la columna codigousuario.');
    }
    final periodIndex = headers.indexWhere((item) => RegExp(r'^\d{4}-\d{2}$').hasMatch(item));
    if (periodIndex < 0) {
      throw Exception('La segunda columna debe tener encabezado de periodo, por ejemplo 2026-01.');
    }
    final period = headers[periodIndex].toUpperCase();

    final rows = table.rows.skip(1).map((row) {
      return {
        'codigoUsuario': _cell(row, codeIndex).toUpperCase(),
        'lecturaActual': _cell(row, periodIndex),
      };
    }).where((row) {
      return row.values.any((value) => value.trim().isNotEmpty);
    }).toList();

    return _ParsedConsumptionImport(period: period, rows: rows);
  }

  String _cell(List<xls.Data?> row, int index) {
    if (index >= row.length) {
      return '';
    }
    return _cellValue(row[index]);
  }

  String _cellValue(xls.Data? cell) {
    final value = cell?.value;
    if (value == null) {
      return '';
    }
    final text = value.toString().trim();
    return text.toLowerCase() == 'null' ? '' : text;
  }

  Future<void> _importRows() async {
    final period = _period;
    if (period == null || period.isEmpty) {
      setState(() => _message = 'Selecciona un archivo con periodo valido.');
      return;
    }
    setState(() {
      _isBusy = true;
      _message = null;
      _summary = null;
    });
    try {
      final summary = await _service.importReadings(period: period, rows: _rows);
      setState(() {
        _summary = summary;
        _message =
            'Importacion finalizada: ${summary.imported} importados, ${summary.ignored} ignorados, ${summary.failed} con error.';
      });
    } catch (error) {
      setState(() => _message = 'No fue posible importar: $error');
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _downloadIgnoredRows() async {
    final summary = _summary;
    if (summary == null || summary.ignoredRows.isEmpty) {
      return;
    }
    final excel = xls.Excel.createExcel();
    final sheet = excel['ignorados'];
    sheet.appendRow([
      xls.TextCellValue('fila'),
      xls.TextCellValue('codigousuario'),
      xls.TextCellValue('codigocontador'),
      xls.TextCellValue('periodo'),
      xls.TextCellValue('motivo'),
    ]);
    for (final item in summary.ignoredRows) {
      sheet.appendRow([
        xls.IntCellValue(item.rowNumber),
        xls.TextCellValue(item.codigoUsuario ?? ''),
        xls.TextCellValue(item.codigoContador ?? ''),
        xls.TextCellValue(summary.period),
        xls.TextCellValue(item.message ?? ''),
      ]);
    }
    excel.setDefaultSheet('ignorados');
    final bytes = excel.encode();
    if (bytes == null) {
      return;
    }
    await saveConsumptionImportFile(
      bytes: Uint8List.fromList(bytes),
      fileName: 'consumos_ignorados_${summary.period}.xlsx',
    );
  }
}

class _ParsedConsumptionImport {
  const _ParsedConsumptionImport({
    required this.period,
    required this.rows,
  });

  final String period;
  final List<Map<String, String>> rows;
}

class _PreviewTable extends StatelessWidget {
  const _PreviewTable({
    required this.period,
    required this.rows,
  });

  final String period;
  final List<Map<String, String>> rows;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: DataTable(
        columns: [
          const DataColumn(label: Text('codigousuario')),
          DataColumn(label: Text(period.isEmpty ? 'periodo' : period)),
        ],
        rows: rows
            .map(
              (row) => DataRow(
                cells: [
                  DataCell(Text(row['codigoUsuario'] ?? '')),
                  DataCell(Text(row['lecturaActual'] ?? '')),
                ],
              ),
            )
            .toList(),
      ),
    );
  }
}

class _ImportSummary extends StatelessWidget {
  const _ImportSummary({required this.summary});

  final ConsumptionImportSummary summary;

  @override
  Widget build(BuildContext context) {
    final failedRows = summary.results.where((item) => !item.ok && !item.ignored).toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.brandBlueSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Periodo ${summary.period}: ${summary.imported} importados, ${summary.ignored} ignorados, ${summary.failed} errores.',
          ),
          if (failedRows.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...failedRows.take(8).map(
                  (item) => Text(
                    'Fila ${item.rowNumber}: ${item.message ?? 'Error'}',
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

class _EmptyImportState extends StatelessWidget {
  const _EmptyImportState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Descarga la plantilla, cambia el encabezado 2026-01 por el periodo a importar y escribe las lecturas actuales debajo.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    );
  }
}
