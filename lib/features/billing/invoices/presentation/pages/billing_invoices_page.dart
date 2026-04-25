import 'package:flutter/material.dart';

import '../../../../../core/presentation/text_formatters.dart';
import '../../../../../theme/app_colors.dart';
import '../../../../consumptions/data/consumption_firestore_service.dart';
import '../../../../consumptions/domain/consumption_reading.dart';
import '../../../../users/domain/app_user.dart';
import '../../../payment_methods/data/payment_method_firestore_service.dart';
import '../../../periods/data/billing_period_firestore_service.dart';
import '../../../periods/domain/billing_period.dart';
import '../../../values/data/billing_value_config_firestore_service.dart';
import '../../data/invoice_firestore_service.dart';
import '../../domain/invoice.dart';
import '../services/invoice_printing_service.dart';

class BillingInvoicesPage extends StatefulWidget {
  const BillingInvoicesPage({
    super.key,
    required this.currentUser,
    this.periodService,
    this.consumptionService,
    this.invoiceService,
    this.valueService,
    this.paymentMethodService,
  });

  final AppUser currentUser;
  final BillingPeriodFirestoreService? periodService;
  final ConsumptionFirestoreService? consumptionService;
  final InvoiceFirestoreService? invoiceService;
  final BillingValueConfigFirestoreService? valueService;
  final PaymentMethodFirestoreService? paymentMethodService;

  @override
  State<BillingInvoicesPage> createState() => _BillingInvoicesPageState();
}

class _BillingInvoicesPageState extends State<BillingInvoicesPage> {
  late final BillingPeriodFirestoreService _periodService =
      widget.periodService ?? BillingPeriodFirestoreService();
  late final ConsumptionFirestoreService _consumptionService =
      widget.consumptionService ?? ConsumptionFirestoreService();
  late final InvoiceFirestoreService _invoiceService =
      widget.invoiceService ?? InvoiceFirestoreService();
  late final BillingValueConfigFirestoreService _valueService =
      widget.valueService ?? BillingValueConfigFirestoreService();
  late final PaymentMethodFirestoreService _paymentMethodService =
      widget.paymentMethodService ?? PaymentMethodFirestoreService();
  late final InvoicePrintingService _printingService = InvoicePrintingService();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<BillingPeriod> _periods = const [];
  BillingPeriod? _selectedPeriod;
  List<ConsumptionReading> _readings = const [];
  List<Invoice> _invoices = const [];
  String? _selectedSectorFilter;

  List<ConsumptionReading> get _billableReadings => _readings
      .where(
        (item) =>
            _isReadingReadyForBilling(item) &&
            !item.facturado &&
            !item.pagado,
      )
      .toList();

  List<ConsumptionReading> get _unpreparedReadings => _readings
      .where(
        (item) =>
            !item.facturado &&
            !item.pagado &&
            !_isReadingReadyForBilling(item),
      )
      .toList();

  List<String> get _availableSectors => _invoices
      .map((item) => _displaySector(item.sector))
      .where((item) => item.isNotEmpty && item != 'No registrado')
      .toSet()
      .toList()
    ..sort();

  List<Invoice> get _filteredInvoices {
    final sector = _selectedSectorFilter;
    if (sector == null || sector.isEmpty) {
      return _invoices;
    }
    return _invoices
        .where((item) => _displaySector(item.sector) == sector)
        .toList();
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
      final periods = await _periodService.fetchPeriods();
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
        await _loadPeriodData(selected);
      }
    } catch (error) {
      setState(() => _error = '$error');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadPeriodData(BillingPeriod period) async {
    setState(() {
      _loading = true;
      _error = null;
      _selectedPeriod = period;
    });
    try {
      final results = await Future.wait([
        _consumptionService.fetchReadingsForPeriod(period.id),
        _invoiceService.fetchInvoicesForPeriod(period.id),
      ]);
      setState(() {
        _readings = results[0] as List<ConsumptionReading>;
        _invoices = results[1] as List<Invoice>;
        if (_selectedSectorFilter != null &&
            !_availableSectors.contains(_selectedSectorFilter)) {
          _selectedSectorFilter = null;
        }
      });
    } catch (error) {
      setState(() => _error = '$error');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _generateInvoices() async {
    final period = _selectedPeriod;
    if (period == null || _billableReadings.isEmpty) {
      return;
    }

    if (_unpreparedReadings.isNotEmpty) {
      _showUnpreparedReadings();
      return;
    }

    setState(() => _saving = true);
    try {
      final values = await _valueService.fetchActiveItem();
      if (values == null) {
        throw StateError('No hay configuración activa de valores.');
      }
      final paymentMethods = await _paymentMethodService.fetchItems();
      await _invoiceService.generateInvoicesForReadings(
        period: period,
        readings: _billableReadings,
        values: values,
        paymentMethods: paymentMethods,
        actor: widget.currentUser,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Se generaron ${_billableReadings.length} recibos.'),
        ),
      );
      await _loadPeriodData(period);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No fue posible generar recibos: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _generateInvoiceForReading(ConsumptionReading reading) async {
    final period = _selectedPeriod;
    if (period == null) {
      return;
    }

    setState(() => _saving = true);
    try {
      final values = await _valueService.fetchActiveItem();
      if (values == null) {
        throw StateError('No hay configuración activa de valores.');
      }
      final paymentMethods = await _paymentMethodService.fetchItems();
      await _invoiceService.generateInvoicesForReadings(
        period: period,
        readings: [reading],
        values: values,
        paymentMethods: paymentMethods,
        actor: widget.currentUser,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recibo generado.')),
      );
      await _loadPeriodData(period);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No fue posible generar el recibo: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _regenerateInvoices() async {
    final period = _selectedPeriod;
    if (period == null || _invoices.isEmpty) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Regenerar recibos'),
        content: const Text(
          'Se regenerarán solo los recibos no pagados del período seleccionado con los valores vigentes. Los recibos pagados no se modificarán.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Regenerar'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    setState(() => _saving = true);
    try {
      final values = await _valueService.fetchActiveItem();
      if (values == null) {
        throw StateError('No hay configuración activa de valores.');
      }
      final paymentMethods = await _paymentMethodService.fetchItems();
      final result = await _invoiceService.regenerateInvoicesForPeriod(
        period: period,
        values: values,
        paymentMethods: paymentMethods,
        actor: widget.currentUser,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Recibos regenerados: ${result.regeneratedCount}. Pagados omitidos: ${result.skippedPaidCount}.',
          ),
        ),
      );
      await _loadPeriodData(period);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No fue posible regenerar recibos: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _printInvoice(Invoice invoice) async {
    try {
      await _printingService.printInvoice(invoice);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No fue posible generar el PDF: $error')),
      );
    }
  }

  Future<void> _exportPeriodInvoicesUnified() async {
    final period = _selectedPeriod;
    if (period == null || _invoices.isEmpty) {
      return;
    }
    final result = await showDialog<_ExportDialogResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _ExportInvoicesDialog(
        title: 'Exportar período',
        description:
            'Selecciona si deseas un solo PDF con una hoja por usuario o archivos individuales.',
      ),
    );
    if (result == null) {
      return;
    }
    await _runExport(
      invoices: _invoices,
      fileName: InvoicePrintingService.fileNameForPeriod(period.id),
      mode: result.mode,
    );
  }

  Future<void> _exportSectorInvoicesUnified() async {
    final period = _selectedPeriod;
    if (period == null || _invoices.isEmpty || _availableSectors.isEmpty) {
      return;
    }
    final result = await showDialog<_ExportDialogResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ExportInvoicesDialog(
        title: 'Exportar por sector',
        description:
            'Selecciona el sector y el formato de salida para los recibos del período.',
        sectors: _availableSectors,
      ),
    );
    if (result == null || result.sector == null) {
      return;
    }
    final invoices = _invoices
        .where((item) => _displaySector(item.sector) == result.sector)
        .toList();
    if (invoices.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay recibos para ese sector.')),
      );
      return;
    }
    await _runExport(
      invoices: invoices,
      fileName: InvoicePrintingService.fileNameForSector(
        period.id,
        result.sector!,
      ),
      mode: result.mode,
    );
  }

  // ignore: unused_element
  Future<void> _exportPeriodInvoices() async {
    final period = _selectedPeriod;
    if (period == null || _invoices.isEmpty) {
      return;
    }
    final mode = await _showExportModeDialog(
      title: 'Exportar período',
      description:
          'Selecciona si deseas un solo PDF con una hoja por usuario o archivos individuales.',
    );
    if (mode == null) {
      return;
    }
    await _runExport(
      invoices: _invoices,
      fileName: InvoicePrintingService.fileNameForPeriod(period.id),
      mode: mode,
    );
  }

  // ignore: unused_element
  Future<void> _exportSectorInvoices() async {
    final period = _selectedPeriod;
    if (period == null || _invoices.isEmpty || _availableSectors.isEmpty) {
      return;
    }
    final result = await showDialog<_SectorExportResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _SectorExportDialog(sectors: _availableSectors),
    );
    if (result == null) {
      return;
    }
    final invoices = _invoices
        .where((item) => _displaySector(item.sector) == result.sector)
        .toList();
    if (invoices.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay recibos para ese sector.')),
      );
      return;
    }
    await _runExport(
      invoices: invoices,
      fileName: InvoicePrintingService.fileNameForSector(
        period.id,
        result.sector,
      ),
      mode: result.mode,
    );
  }

  Future<void> _runExport({
    required List<Invoice> invoices,
    required String fileName,
    required _PdfExportMode mode,
  }) async {
    setState(() => _saving = true);
    try {
      if (mode == _PdfExportMode.combined) {
        await _printingService.printInvoices(invoices, fileName: fileName);
      } else {
        await _printingService.shareInvoicesIndividually(invoices);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No fue posible exportar los PDFs: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<_PdfExportMode?> _showExportModeDialog({
    required String title,
    required String description,
  }) {
    return showDialog<_PdfExportMode>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(description),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          OutlinedButton(
            onPressed: () =>
                Navigator.of(context).pop(_PdfExportMode.individual),
            child: const Text('PDFs individuales'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_PdfExportMode.combined),
            child: const Text('Un solo PDF'),
          ),
        ],
      ),
    );
  }

  void _showUnpreparedReadings() {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760, maxHeight: 560),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No preparados para facturar',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Estos usuarios aún no tienen la lectura lista para generar recibo en el período seleccionado.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _unpreparedReadings.isEmpty
                      ? const Center(
                          child: Text('Todos los usuarios están listos.'),
                        )
                      : ListView.separated(
                          itemCount: _unpreparedReadings.length,
                          separatorBuilder: (_, _) => const Divider(height: 20),
                          itemBuilder: (context, index) {
                            final item = _unpreparedReadings[index];
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  toDisplayUserName(item.nombreUsuario),
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Código ${item.codigoUsuario} · Contador ${item.codigoContador}',
                                ),
                                const SizedBox(height: 4),
                                Text(_unpreparedReason(item)),
                              ],
                            );
                          },
                        ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cerrar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _isReadingReadyForBilling(ConsumptionReading item) {
    final previous = item.lecturaAnterior ?? 0;
    return !item.isBlocked && item.lecturaActual >= previous;
  }

  String _unpreparedReason(ConsumptionReading item) {
    final previous = item.lecturaAnterior ?? 0;
    if (item.isBlocked) {
      return 'Tiene el consumo bloqueado o en conflicto.';
    }
    if (item.lecturaActual < previous) {
      return 'La lectura actual es menor a la lectura anterior.';
    }
    return 'Aún no cumple las condiciones mínimas de facturación.';
  }

  String _displaySector(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty || normalized.toLowerCase() == 'na') {
      return 'No registrado';
    }
    return normalized
        .replaceAll('_', ' ')
        .split(RegExp(r'\s+'))
        .where((item) => item.isNotEmpty)
        .map(
          (item) => item[0].toUpperCase() + item.substring(1).toLowerCase(),
        )
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AbsorbPointer(
          absorbing: _saving,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HeaderPanel(
                periods: _periods,
                selectedPeriod: _selectedPeriod,
                billableCount: _billableReadings.length,
                invoiceCount: _invoices.length,
                unpreparedCount: _unpreparedReadings.length,
                onPeriodChanged: (period) {
                  if (period != null) {
                    _loadPeriodData(period);
                  }
                },
                onGenerate: _billableReadings.isEmpty || _saving
                    ? null
                    : _generateInvoices,
                onRegenerate: _invoices.isEmpty || _saving
                    ? null
                    : _regenerateInvoices,
                onExportPeriod: _invoices.isEmpty || _saving
                    ? null
                    : _exportPeriodInvoicesUnified,
                onExportSector:
                    _invoices.isEmpty || _availableSectors.isEmpty || _saving
                    ? null
                    : _exportSectorInvoicesUnified,
                onShowUnprepared: _unpreparedReadings.isEmpty
                    ? null
                    : _showUnpreparedReadings,
              ),
              const SizedBox(height: 16),
              if (_availableSectors.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Todos los sectores'),
                      selected: _selectedSectorFilter == null,
                      onSelected: (_) {
                        setState(() => _selectedSectorFilter = null);
                      },
                    ),
                    ..._availableSectors.map(
                      (sector) => ChoiceChip(
                        label: Text(sector),
                        selected: _selectedSectorFilter == sector,
                        onSelected: (_) {
                          setState(() => _selectedSectorFilter = sector);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(color: Colors.red.shade800),
                  ),
                ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _billableReadings.isEmpty && _invoices.isEmpty
                        ? const Center(
                            child: Text(
                              'No hay recibos generados para este período.',
                            ),
                          )
                        : ListView.separated(
                            itemCount:
                                _billableReadings.length + _filteredInvoices.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              if (index < _billableReadings.length) {
                                return _BillableReadingCard(
                                  reading: _billableReadings[index],
                                  onGenerate: () => _generateInvoiceForReading(
                                    _billableReadings[index],
                                  ),
                                );
                              }
                              return _InvoicePreviewCard(
                                invoice: _filteredInvoices[index - _billableReadings.length],
                                onPrint: () => _printInvoice(
                                  _filteredInvoices[index - _billableReadings.length],
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
        if (_saving)
          Positioned.fill(
            child: ColoredBox(
              color: AppColors.textPrimary.withValues(alpha: 0.16),
              child: const Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }
}

class _BillableReadingCard extends StatelessWidget {
  const _BillableReadingCard({
    required this.reading,
    required this.onGenerate,
  });

  final ConsumptionReading reading;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    final previousReading = reading.lecturaAnterior ?? 0;
    final consumption = reading.consumoCalculado ??
        (reading.lecturaActual - previousReading).clamp(0, 1 << 31).toInt();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF8E9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEEDFA8)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final info = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                toDisplayUserName(reading.nombreUsuario),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text('Pendiente por facturar · Código ${reading.codigoUsuario} · Contador ${reading.codigoContador}'),
              const SizedBox(height: 6),
              Text('Lectura anterior: $previousReading · Actual: ${reading.lecturaActual} · Consumo: $consumption m³'),
            ],
          );
          final action = ElevatedButton.icon(
            onPressed: onGenerate,
            icon: const Icon(Icons.receipt_rounded),
            label: const Text('Generar individual'),
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [info, const SizedBox(height: 16), action],
            );
          }
          return Row(
            children: [
              Expanded(child: info),
              const SizedBox(width: 12),
              action,
            ],
          );
        },
      ),
    );
  }
}

// ignore: unused_element
class _Header extends StatelessWidget {
  const _Header({
    required this.periods,
    required this.selectedPeriod,
    required this.billableCount,
    required this.invoiceCount,
    required this.unpreparedCount,
    required this.onPeriodChanged,
    required this.onGenerate,
    required this.onRegenerate,
    required this.onExportPeriod,
    required this.onExportSector,
    required this.onShowUnprepared,
  });

  final List<BillingPeriod> periods;
  final BillingPeriod? selectedPeriod;
  final int billableCount;
  final int invoiceCount;
  final int unpreparedCount;
  final ValueChanged<BillingPeriod?> onPeriodChanged;
  final VoidCallback? onGenerate;
  final VoidCallback? onRegenerate;
  final VoidCallback? onExportPeriod;
  final VoidCallback? onExportSector;
  final VoidCallback? onShowUnprepared;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final info = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Facturación', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Selecciona un período y genera recibos para los consumos pendientes de facturar.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _Metric(label: 'Pendientes listos', value: '$billableCount'),
                _Metric(label: 'No preparados', value: '$unpreparedCount'),
                _Metric(label: 'Recibos', value: '$invoiceCount'),
              ],
            ),
          ],
        );
        final actions = Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 240,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Período', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<BillingPeriod>(
                    isExpanded: true,
                    initialValue: selectedPeriod,
                    decoration: const InputDecoration(
                      hintText: 'Selecciona un período',
                    ),
                    items: periods
                        .map(
                          (period) => DropdownMenuItem(
                            value: period,
                            child: Text(_periodLabel(period)),
                          ),
                        )
                        .toList(),
                    onChanged: onPeriodChanged,
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: onGenerate,
              style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
              icon: const Icon(Icons.receipt_long_rounded),
              label: const Text('Generar recibos'),
            ),
            OutlinedButton.icon(
              onPressed: onRegenerate,
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Regenerar'),
            ),
            OutlinedButton.icon(
              onPressed: onExportPeriod,
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              icon: const Icon(Icons.picture_as_pdf_rounded),
              label: const Text('PDF período'),
            ),
            OutlinedButton.icon(
              onPressed: onExportSector,
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              icon: const Icon(Icons.filter_alt_rounded),
              label: const Text('PDF por sector'),
            ),
            OutlinedButton.icon(
              onPressed: onShowUnprepared,
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              icon: const Icon(Icons.playlist_add_check_circle_outlined),
              label: const Text('No preparados'),
            ),
          ],
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [info, const SizedBox(height: 16), actions],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: info),
            const SizedBox(width: 16),
            actions,
          ],
        );
      },
    );
  }
}

class _InvoicePreviewCard extends StatelessWidget {
  const _InvoicePreviewCard({
    required this.invoice,
    required this.onPrint,
  });

  final Invoice invoice;
  final VoidCallback onPrint;

  @override
  Widget build(BuildContext context) {
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
            'ASOCIACIÓN DE USUARIOS DEL ACUEDUCTO DE LAS VEREDAS DE QUITASOL Y JAZMÍN',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: onPrint,
              icon: const Icon(Icons.picture_as_pdf_rounded),
              label: const Text('PDF'),
            ),
          ),
          const SizedBox(height: 4),
          const Text('Municipio de Viotá · NIT 808.000.868-7'),
          const SizedBox(height: 14),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              _LabelValue(label: 'Código usuario', value: invoice.codigoUsuario),
              _LabelValue(label: 'Contador', value: invoice.codigoContador),
              _LabelValue(label: 'Usuario', value: toDisplayUserName(invoice.nombreUsuario)),
              _LabelValue(label: 'Período facturado', value: invoice.periodo),
              _LabelValue(label: 'Generado', value: _formatDate(invoice.fechaGeneracion)),
              _LabelValue(label: 'Vence', value: _formatDate(invoice.fechaVencimiento)),
              _LabelValue(label: 'Consumo mes m³', value: '${invoice.consumoM3}'),
              _LabelValue(label: 'Lectura anterior', value: '${invoice.lecturaAnterior ?? '-'}'),
              _LabelValue(label: 'Lectura actual', value: '${invoice.lecturaActual}'),
            ],
          ),
          const SizedBox(height: 14),
          ...invoice.lineas.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(child: Text(item.descripcion)),
                  Text('${item.cantidad} x ${_formatCurrency(item.valorUnitario)}'),
                  const SizedBox(width: 14),
                  SizedBox(
                    width: 96,
                    child: Text(
                      _formatCurrency(item.valorTotal),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 24),
          if (invoice.mediosPagoTexto.isNotEmpty) ...[
            Text('Medios de pago', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(invoice.mediosPagoTexto),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: Text(
                  invoice.mensaje ?? '',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'Total: ${_formatCurrency(invoice.total)}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
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

class _HeaderPanel extends StatelessWidget {
  const _HeaderPanel({
    required this.periods,
    required this.selectedPeriod,
    required this.billableCount,
    required this.invoiceCount,
    required this.unpreparedCount,
    required this.onPeriodChanged,
    required this.onGenerate,
    required this.onRegenerate,
    required this.onExportPeriod,
    required this.onExportSector,
    required this.onShowUnprepared,
  });

  final List<BillingPeriod> periods;
  final BillingPeriod? selectedPeriod;
  final int billableCount;
  final int invoiceCount;
  final int unpreparedCount;
  final ValueChanged<BillingPeriod?> onPeriodChanged;
  final VoidCallback? onGenerate;
  final VoidCallback? onRegenerate;
  final VoidCallback? onExportPeriod;
  final VoidCallback? onExportSector;
  final VoidCallback? onShowUnprepared;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 920;

        final overviewCard = Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Facturación', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                'Selecciona un período, genera los recibos listos y usa las acciones masivas desde este panel.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _Metric(label: 'Pendientes listos', value: '$billableCount'),
                  _Metric(label: 'No preparados', value: '$unpreparedCount'),
                  _Metric(label: 'Recibos', value: '$invoiceCount'),
                ],
              ),
            ],
          ),
        );

        final controlCard = Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Período de trabajo', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              DropdownButtonFormField<BillingPeriod>(
                isExpanded: true,
                initialValue: selectedPeriod,
                decoration: const InputDecoration(
                  hintText: 'Selecciona un período',
                ),
                items: periods
                    .map(
                      (period) => DropdownMenuItem(
                        value: period,
                        child: Text(_periodLabel(period)),
                      ),
                    )
                    .toList(),
                onChanged: onPeriodChanged,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ElevatedButton.icon(
                    onPressed: onGenerate,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    icon: const Icon(Icons.receipt_long_rounded),
                    label: const Text('Generar recibos'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onRegenerate,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Regenerar'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onExportPeriod,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    icon: const Icon(Icons.picture_as_pdf_rounded),
                    label: const Text('PDF período'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onExportSector,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    icon: const Icon(Icons.filter_alt_rounded),
                    label: const Text('PDF por sector'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onShowUnprepared,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    icon: const Icon(Icons.playlist_add_check_circle_outlined),
                    label: const Text('No preparados'),
                  ),
                ],
              ),
            ],
          ),
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              overviewCard,
              const SizedBox(height: 12),
              controlCard,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 5, child: overviewCard),
            const SizedBox(width: 12),
            Expanded(flex: 6, child: controlCard),
          ],
        );
      },
    );
  }
}

class _LabelValue extends StatelessWidget {
  const _LabelValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      child: Text('$label: $value'),
    );
  }
}

class _ExportInvoicesDialog extends StatefulWidget {
  const _ExportInvoicesDialog({
    required this.title,
    required this.description,
    this.sectors = const [],
  });

  final String title;
  final String description;
  final List<String> sectors;

  @override
  State<_ExportInvoicesDialog> createState() => _ExportInvoicesDialogState();
}

class _ExportInvoicesDialogState extends State<_ExportInvoicesDialog> {
  late String? _sector = widget.sectors.isEmpty ? null : widget.sectors.first;
  _PdfExportMode _mode = _PdfExportMode.combined;

  bool get _requiresSector => widget.sectors.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              Text(widget.description),
              if (_requiresSector) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _sector,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Sector'),
                  items: widget.sectors
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(item),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _sector = value),
                ),
              ],
              const SizedBox(height: 16),
              SegmentedButton<_PdfExportMode>(
                segments: const [
                  ButtonSegment(
                    value: _PdfExportMode.combined,
                    label: Text('Un solo PDF'),
                  ),
                  ButtonSegment(
                    value: _PdfExportMode.individual,
                    label: Text('Individuales'),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (selection) {
                  setState(() => _mode = selection.first);
                },
              ),
              const SizedBox(height: 24),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 12,
                runSpacing: 12,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    onPressed: _requiresSector && _sector == null
                        ? null
                        : () => Navigator.of(context).pop(
                              _ExportDialogResult(
                                sector: _sector,
                                mode: _mode,
                              ),
                            ),
                    child: const Text('Exportar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExportDialogResult {
  const _ExportDialogResult({
    this.sector,
    required this.mode,
  });

  final String? sector;
  final _PdfExportMode mode;
}

class _SectorExportResult {
  const _SectorExportResult({
    required this.sector,
    required this.mode,
  });

  final String sector;
  final _PdfExportMode mode;
}

class _SectorExportDialog extends StatelessWidget {
  const _SectorExportDialog({required this.sectors});

  final List<String> sectors;

  @override
  Widget build(BuildContext context) {
    return _ExportInvoicesDialog(
      title: 'Exportar por sector',
      description:
          'Selecciona el sector y el formato de salida para los recibos del período.',
      sectors: sectors,
    );
  }
}

enum _PdfExportMode {
  combined,
  individual,
}

String _periodLabel(BillingPeriod period) {
  return '${period.clave} · ${toDisplayText(period.nombre)}${period.vigente ? ' · Vigente' : ''}';
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
