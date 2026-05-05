import 'dart:typed_data';
import 'dart:ui';

import 'package:excel/excel.dart' as xls;
import 'package:flutter/material.dart';

import '../../../../core/platform/excel_file_picker_stub.dart'
    if (dart.library.html) '../../../../core/platform/excel_file_picker_web.dart';
import '../../../../theme/app_colors.dart';
import '../../data/user_admin_functions_service.dart';
import '../../domain/app_user.dart';
import 'user_import_file_exporter_stub.dart'
    if (dart.library.html) 'user_import_file_exporter_web.dart';

class UsersImportPage extends StatefulWidget {
  const UsersImportPage({
    super.key,
    required this.currentUser,
    this.adminFunctionsService,
  });

  final AppUser currentUser;
  final UserAdminFunctionsService? adminFunctionsService;

  @override
  State<UsersImportPage> createState() => _UsersImportPageState();
}

class _UsersImportPageState extends State<UsersImportPage> {
  static const _columns = [
    'tipousuario',
    'sector',
    'numcontador',
    'codigousuario',
    'documento',
    'celular',
    'nombre',
    'correo',
  ];
  static const _mergeColumns = [
    'sector',
    'numcontador',
    'codigousuario',
    'documento',
    'nombre',
  ];

  late final UserAdminFunctionsService _service =
      widget.adminFunctionsService ?? UserAdminFunctionsService();

  bool _isBusy = false;
  String? _message;
  List<Map<String, String>> _rows = const [];
  UserImportSummary? _summary;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Importar usuarios',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Carga usuarios cliente desde una plantilla Excel. El rol se guarda como cliente, el estado como activo y el tipo de documento como cc.',
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
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                  ),
                  icon: const Icon(Icons.upload_file_rounded),
                  label: const Text('Seleccionar archivo'),
                ),
                FilledButton.icon(
                  onPressed: _isBusy || _rows.isEmpty ? null : _importRows,
                  icon: const Icon(Icons.cloud_upload_rounded),
                  label: const Text('Importar registros'),
                ),
                if (widget.currentUser.superAdmin)
                  OutlinedButton.icon(
                    onPressed: _isBusy ? null : _pickMergeFile,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    icon: const Icon(Icons.merge_type_rounded),
                    label: const Text('Migrar y unir por documento'),
                  ),
              ],
            ),
            if (_message case final message?) ...[
              const SizedBox(height: 12),
              Text(message, style: Theme.of(context).textTheme.bodyMedium),
            ],
            if (_summary != null) ...[
              const SizedBox(height: 12),
              _ImportSummaryCard(summary: _summary!),
            ],
            const SizedBox(height: 16),
            Expanded(
              child: _rows.isEmpty
                  ? const _ImportEmptyState()
                  : _ImportPreviewTable(rows: _rows, columns: _columns),
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
                        Text('Procesando importación...'),
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
    final sheet = excel['usuarios'];
    sheet.appendRow(_columns.map((item) => xls.TextCellValue(item)).toList());
    excel.setDefaultSheet('usuarios');
    final bytes = excel.encode();
    if (bytes == null) {
      setState(() => _message = 'No fue posible generar la plantilla.');
      return;
    }
    await saveUserImportTemplate(
      bytes: Uint8List.fromList(bytes),
      fileName: 'plantilla_import_usuarios.xlsx',
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
      final parsedRows = _parseWorkbook(bytes);
      setState(() {
        _rows = parsedRows;
        _message = 'Archivo cargado: ${parsedRows.length} registros listos.';
      });
    } catch (error) {
      setState(() => _message = 'No fue posible leer el archivo: $error');
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  List<Map<String, String>> _parseWorkbook(Uint8List bytes) {
    final workbook = xls.Excel.decodeBytes(bytes);
    if (workbook.tables.isEmpty) {
      return const [];
    }
    final table = workbook.tables.values.first;
    if (table.rows.isEmpty) {
      return const [];
    }

    final header = table.rows.first
        .map((cell) => _normalizeHeader(cell?.value.toString() ?? ''))
        .toList();
    final indexes = {
      for (final column in _columns) column: header.indexOf(column),
    };
    final missing = indexes.entries
        .where((entry) => entry.value < 0)
        .map((entry) => entry.key)
        .toList();
    if (missing.isNotEmpty) {
      throw Exception('Faltan columnas: ${missing.join(', ')}');
    }

    return table.rows
        .skip(1)
        .map((row) {
          return {
            'tipoUsuario': _cell(row, indexes['tipousuario']!),
            'sector': _cell(row, indexes['sector']!),
            'numeroContador': _cell(row, indexes['numcontador']!).toUpperCase(),
            'codigoUsuario': _cell(
              row,
              indexes['codigousuario']!,
            ).toUpperCase(),
            'numeroDocumento': _cell(row, indexes['documento']!),
            'numeroContacto': _cell(row, indexes['celular']!),
            'nombre': _cell(row, indexes['nombre']!),
            'correo': _cell(row, indexes['correo']!).toLowerCase(),
          };
        })
        .where((row) {
          return row.values.any((value) => value.trim().isNotEmpty);
        })
        .toList();
  }

  List<Map<String, String>> _parseMergeWorkbook(Uint8List bytes) {
    final workbook = xls.Excel.decodeBytes(bytes);
    if (workbook.tables.isEmpty) {
      return const [];
    }
    final table = workbook.tables.values.first;
    if (table.rows.isEmpty) {
      return const [];
    }

    final header = table.rows.first
        .map((cell) => _normalizeHeader(cell?.value.toString() ?? ''))
        .toList();
    final indexes = {
      for (final column in _mergeColumns) column: header.indexOf(column),
    };
    final missing = indexes.entries
        .where((entry) => entry.value < 0)
        .map((entry) => entry.key)
        .toList();
    if (missing.isNotEmpty) {
      throw Exception('Faltan columnas: ${missing.join(', ')}');
    }

    return table.rows
        .skip(1)
        .map((row) {
          return {
            'sector': _cell(row, indexes['sector']!),
            'numeroContador': _cell(row, indexes['numcontador']!).toUpperCase(),
            'codigoUsuario': _cell(
              row,
              indexes['codigousuario']!,
            ).toUpperCase(),
            'numeroDocumento': _cell(row, indexes['documento']!),
            'nombre': _cell(row, indexes['nombre']!),
          };
        })
        .where((row) {
          return row.values.any((value) => value.trim().isNotEmpty);
        })
        .toList();
  }

  String _cell(List<xls.Data?> row, int index) {
    if (index >= row.length) {
      return '';
    }
    final value = row[index]?.value;
    if (value == null) {
      return '';
    }
    final text = value.toString().trim();
    return text.toLowerCase() == 'null' ? '' : text;
  }

  String _normalizeHeader(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');
  }

  Future<void> _importRows() async {
    setState(() {
      _isBusy = true;
      _message = null;
      _summary = null;
    });
    try {
      final summary = await _service.importMigratedUsers(_rows);
      setState(() {
        _summary = summary;
        _message =
            'Importación finalizada: ${summary.imported} importados, ${summary.failed} con error.';
      });
    } catch (error) {
      setState(() => _message = 'No fue posible importar: $error');
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _pickMergeFile() async {
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
      final parsedRows = _parseMergeWorkbook(bytes);
      final summary = await _service.mergeClientUsersByDocument(parsedRows);
      setState(() {
        _rows = parsedRows;
        _summary = summary;
        _message =
            'Migración finalizada: ${summary.imported} usuarios unificados, ${summary.failed} con error.';
      });
    } catch (error) {
      setState(
        () => _message = 'No fue posible migrar y unir usuarios: $error',
      );
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }
}

class _ImportPreviewTable extends StatelessWidget {
  const _ImportPreviewTable({required this.rows, required this.columns});

  final List<Map<String, String>> rows;
  final List<String> columns;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: columns
              .map((item) => DataColumn(label: Text(item)))
              .toList(),
          rows: rows.map((row) {
            return DataRow(
              cells: [
                DataCell(Text(row['tipoUsuario'] ?? '')),
                DataCell(Text(row['sector'] ?? '')),
                DataCell(Text(row['numeroContador'] ?? '')),
                DataCell(Text(row['codigoUsuario'] ?? '')),
                DataCell(Text(row['numeroDocumento'] ?? '')),
                DataCell(Text(row['numeroContacto'] ?? '')),
                DataCell(Text(row['nombre'] ?? '')),
                DataCell(Text(row['correo'] ?? '')),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _ImportSummaryCard extends StatelessWidget {
  const _ImportSummaryCard({required this.summary});

  final UserImportSummary summary;

  @override
  Widget build(BuildContext context) {
    final failedRows = summary.results.where((item) => !item.ok).toList();
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
          Text('Importados: ${summary.imported} · Errores: ${summary.failed}'),
          if (failedRows.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...failedRows
                .take(8)
                .map(
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

class _ImportEmptyState extends StatelessWidget {
  const _ImportEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Descarga la plantilla, completa los registros y selecciona el archivo para revisar la vista previa.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    );
  }
}
