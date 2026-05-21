import 'dart:typed_data';

import 'package:excel/excel.dart' as xls;
import 'package:flutter/material.dart';

import '../../../../theme/app_colors.dart';
import '../../../billing/invoices/data/invoice_firestore_service.dart';
import '../../../billing/invoices/domain/invoice.dart';
import '../../../billing/periods/data/billing_period_firestore_service.dart';
import '../../../billing/periods/domain/billing_period.dart';
import '../../../users/data/user_firestore_service.dart';
import '../../data/consumption_firestore_service.dart';
import '../../domain/consumption_reading.dart';
import 'consumption_reports_file_exporter_stub.dart'
    if (dart.library.html) 'consumption_reports_file_exporter_web.dart';

class ConsumptionReportsAdminPage extends StatefulWidget {
  const ConsumptionReportsAdminPage({
    super.key,
    this.periodService,
    this.firestoreService,
    this.invoiceService,
    this.userService,
  });

  final BillingPeriodFirestoreService? periodService;
  final ConsumptionFirestoreService? firestoreService;
  final InvoiceFirestoreService? invoiceService;
  final UserFirestoreService? userService;

  @override
  State<ConsumptionReportsAdminPage> createState() =>
      _ConsumptionReportsAdminPageState();
}

class _ConsumptionReportsAdminPageState
    extends State<ConsumptionReportsAdminPage> {
  late final BillingPeriodFirestoreService _periodService =
      widget.periodService ?? BillingPeriodFirestoreService();
  late final ConsumptionFirestoreService _firestoreService =
      widget.firestoreService ?? ConsumptionFirestoreService();
  late final InvoiceFirestoreService _invoiceService =
      widget.invoiceService ?? InvoiceFirestoreService();
  late final UserFirestoreService _userService =
      widget.userService ?? UserFirestoreService();

  bool _loading = true;
  String? _error;
  BillingPeriod? _selectedPeriod;
  List<BillingPeriod> _periods = const [];

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
      setState(() {
        _periods = periods;
        _selectedPeriod = selected;
      });
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
    return Stack(
      children: [
        AbsorbPointer(
          absorbing: _loading,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reporte de consumos',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Genera el archivo de consumos y cartera asociada para el periodo seleccionado.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 20),
              Container(
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
                      width: 280,
                      child: DropdownButtonFormField<BillingPeriod>(
                        isExpanded: true,
                        initialValue: _selectedPeriod,
                        decoration: const InputDecoration(labelText: 'Periodo'),
                        items: _periods
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
                        onChanged: (period) {
                          setState(() => _selectedPeriod = period);
                        },
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _selectedPeriod == null ? null : _generate,
                      icon: const Icon(Icons.file_download_rounded),
                      label: const Text('Generar Excel'),
                    ),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: Colors.red.shade800)),
              ],
              const SizedBox(height: 20),
              Expanded(
                child: Center(
                  child: Text(
                    _selectedPeriod == null
                        ? 'No hay periodos disponibles para generar el reporte.'
                        : 'Selecciona el periodo y genera el Excel.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_loading)
          Positioned.fill(
            child: ColoredBox(
              color: AppColors.textPrimary.withValues(alpha: 0.14),
              child: const Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
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
      final readings = await _firestoreService.fetchReadingsReport(
        period: period.id,
      );
      final invoicesByReading = await _fetchInvoicesByReading(readings);
      final documentByUserCode = await _fetchDocumentByUserCode();
      final paidReadings = readings
          .where((item) {
            final invoice = invoicesByReading[_InvoiceKey.fromReading(item)];
            return (invoice?.valorPagado ?? 0) > 0;
          })
          .toList();
      await _export(
        periodId: period.id,
        items: paidReadings,
        invoicesByReading: invoicesByReading,
        documentByUserCode: documentByUserCode,
      );
    } catch (error) {
      if (mounted) {
        setState(() => _error = '$error');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _export({
    required String periodId,
    required List<ConsumptionReading> items,
    required Map<_InvoiceKey, Invoice> invoicesByReading,
    required Map<String, String> documentByUserCode,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final excel = xls.Excel.createExcel();
    final sheet = excel['reporte'];
    sheet.appendRow([
      xls.TextCellValue('periodo'),
      xls.TextCellValue('codigo_usuario'),
      xls.TextCellValue('identificacion_usuario'),
      xls.TextCellValue('nombre_usuario'),
      xls.TextCellValue('codigo_contador'),
      xls.TextCellValue('consumo_calculado'),
      xls.TextCellValue('valor_pagado'),
    ]);
    var totalConsumoCalculado = 0;
    var totalValorPagado = 0;
    for (final item in items) {
      final invoice = invoicesByReading[_InvoiceKey.fromReading(item)];
      final consumption = item.consumoCalculado;
      final paidAmount = invoice?.valorPagado ?? 0;
      if (consumption != null) {
        totalConsumoCalculado += consumption;
      }
      totalValorPagado += paidAmount;
      sheet.appendRow([
        xls.TextCellValue(item.periodoActual),
        xls.TextCellValue(item.codigoUsuario),
        xls.TextCellValue(
          documentByUserCode[_normalizeUserCode(item.codigoUsuario)] ?? '',
        ),
        xls.TextCellValue(item.nombreUsuario),
        xls.TextCellValue(item.codigoContador),
        consumption == null
            ? xls.TextCellValue('')
            : xls.IntCellValue(consumption),
        xls.IntCellValue(paidAmount),
      ]);
    }
    sheet.appendRow([
      xls.TextCellValue('TOTAL'),
      xls.TextCellValue(''),
      xls.TextCellValue(''),
      xls.TextCellValue(''),
      xls.IntCellValue(totalConsumoCalculado),
      xls.IntCellValue(totalValorPagado),
    ]);
    excel.setDefaultSheet('reporte');
    final bytes = excel.encode();
    if (bytes == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No fue posible generar el Excel.')),
      );
      return;
    }
    await saveConsumptionReportFile(
      bytes: Uint8List.fromList(bytes),
      fileName: 'consumos_$periodId.xlsx',
    );
    messenger.showSnackBar(
      const SnackBar(content: Text('Reporte Excel descargado.')),
    );
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

  Future<Map<String, String>> _fetchDocumentByUserCode() async {
    final users = await _userService.fetchAllUsers();
    final documents = <String, String>{};
    for (final user in users) {
      final document = user.numeroDocumento.trim();
      if (document.isEmpty) {
        continue;
      }
      for (final code in user.codigosUsuario) {
        final normalizedCode = _normalizeUserCode(code.codigoUsuario);
        if (normalizedCode.isNotEmpty) {
          documents[normalizedCode] = document;
        }
      }
      final legacyCode = _normalizeUserCode(user.codigoUsuario);
      if (legacyCode.isNotEmpty) {
        documents[legacyCode] = document;
      }
    }
    return documents;
  }
}

String _normalizeUserCode(String value) {
  return value.trim().toUpperCase();
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

String _periodLabel(BillingPeriod period) {
  return '${period.clave} - ${period.nombre}${period.vigente ? ' - Vigente' : ''}';
}
