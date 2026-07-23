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

part 'billing_invoices_page_components.dart';

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
  String _search = '';
  String _searchField = 'nombre';
  List<BillingPeriod> _periods = const [];
  BillingPeriod? _selectedPeriod;
  List<ConsumptionReading> _readings = const [];
  List<Invoice> _invoices = const [];
  String? _selectedSectorFilter;
  final TextEditingController _searchController = TextEditingController();

  List<ConsumptionReading> get _billableReadings => _readings
      .where(
        (item) =>
            _isReadingReadyForBilling(item) && !item.facturado && !item.pagado,
      )
      .toList();

  List<ConsumptionReading> get _unpreparedReadings => _readings
      .where(
        (item) =>
            !item.facturado && !item.pagado && !_isReadingReadyForBilling(item),
      )
      .toList();

  List<ConsumptionReading> get _filteredBillableReadings {
    final query = _search.trim().toLowerCase();
    final readings = _billableReadings;
    if (query.isEmpty) {
      return readings;
    }
    return readings
        .where((item) => _matchesReadingSearch(item, query))
        .toList();
  }

  List<String> get _availableSectors =>
      _invoices
          .map((item) => _displaySector(item.sector))
          .where((item) => item.isNotEmpty && item != 'No registrado')
          .toSet()
          .toList()
        ..sort();

  List<Invoice> get _filteredInvoices {
    final sector = _selectedSectorFilter;
    final query = _search.trim().toLowerCase();
    return _invoices.where((item) {
      if (sector != null &&
          sector.isNotEmpty &&
          _displaySector(item.sector) != sector) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      return _matchesInvoiceSearch(item, query);
    }).toList();
  }

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
        _selectedPeriod = periods.contains(selected)
            ? selected
            : (periods.isEmpty ? null : periods.first);
      });
      if (_selectedPeriod != null) {
        await _loadPeriodData(_selectedPeriod!);
      }
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

  Future<void> _loadPeriodData(BillingPeriod period) async {
    if (!mounted) {
      return;
    }
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
      if (!mounted) {
        return;
      }
      setState(() {
        _readings = results[0] as List<ConsumptionReading>;
        _invoices = results[1] as List<Invoice>;
        if (_selectedSectorFilter != null &&
            !_availableSectors.contains(_selectedSectorFilter)) {
          _selectedSectorFilter = null;
        }
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

  Future<void> _generateInvoices() async {
    final period = _selectedPeriod;
    final billableReadings = _filteredBillableReadings;
    final unpreparedReadings = _unpreparedReadings;
    if (period == null || billableReadings.isEmpty) {
      return;
    }

    setState(() => _saving = true);
    try {
      final values = await _valueService.fetchApplicableItemForPeriod(
        period.id,
      );
      if (values == null) {
        throw StateError('No hay configuracion activa de valores.');
      }
      final paymentMethods = await _paymentMethodService.fetchItems();
      await _invoiceService.generateInvoicesForReadings(
        period: period,
        readings: billableReadings,
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
            unpreparedReadings.isEmpty
                ? 'Se generaron ${billableReadings.length} recibos.'
                : 'Se generaron ${billableReadings.length} recibos. Omitidos por revisar: ${unpreparedReadings.length}.',
          ),
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
      final values = await _valueService.fetchApplicableItemForPeriod(
        period.id,
      );
      if (values == null) {
        throw StateError('No hay configuracion activa de valores.');
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Recibo generado.')));
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
          'Se regeneraran solo los recibos no pagados del periodo seleccionado con los valores aplicables a ese periodo. Los recibos pagados no se modificaran.',
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
      final values = await _valueService.fetchApplicableItemForPeriod(
        period.id,
      );
      if (values == null) {
        throw StateError('No hay configuracion activa de valores.');
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

  Future<void> _regenerateInvoice(Invoice invoice) async {
    final period = _selectedPeriod;
    if (period == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Regenerar recibo'),
        content: Text(
          'Se regenerara el recibo de ${toDisplayUserName(invoice.nombreUsuario)} con los valores aplicables a ${period.id}. Los recibos pagados no se pueden modificar.',
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
      final values = await _valueService.fetchApplicableItemForPeriod(
        period.id,
      );
      if (values == null) {
        throw StateError('No hay configuracion activa de valores.');
      }
      final paymentMethods = await _paymentMethodService.fetchItems();
      await _invoiceService.regenerateInvoice(
        period: period,
        existing: invoice,
        values: values,
        paymentMethods: paymentMethods,
        actor: widget.currentUser,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Recibo regenerado.')));
      await _loadPeriodData(period);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No fue posible regenerar el recibo: $error')),
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
        title: 'Exportar periodo',
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
            'Selecciona el sector y el formato de salida para los recibos del periodo.',
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
      title: 'Exportar periodo',
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
                  'Estos usuarios aun no tienen la lectura lista para generar recibo en el periodo seleccionado.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _unpreparedReadings.isEmpty
                      ? const Center(
                          child: Text('Todos los usuarios estan listos.'),
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
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Codigo ${item.codigoUsuario} - Contador ${item.codigoContador}',
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
    return 'Aun no cumple las condiciones minimas de facturacion.';
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
        .map((item) => item[0].toUpperCase() + item.substring(1).toLowerCase())
        .join(' ');
  }

  bool _matchesInvoiceSearch(Invoice item, String query) {
    return switch (_searchField) {
      'codigoUsuario' => item.codigoUsuario.toLowerCase().contains(query),
      'contador' => item.codigoContador.toLowerCase().contains(query),
      _ => item.nombreUsuario.toLowerCase().contains(query),
    };
  }

  bool _matchesReadingSearch(ConsumptionReading item, String query) {
    return switch (_searchField) {
      'codigoUsuario' => item.codigoUsuario.toLowerCase().contains(query),
      'contador' => item.codigoContador.toLowerCase().contains(query),
      _ => item.nombreUsuario.toLowerCase().contains(query),
    };
  }

  @override
  Widget build(BuildContext context) {
    final billableReadings = _filteredBillableReadings;
    final unpreparedReadings = _unpreparedReadings;
    final availableSectors = _availableSectors;
    final filteredInvoices = _filteredInvoices;
    final totalItems = billableReadings.length + filteredInvoices.length;
    final invoicesList = _loading
        ? const Center(child: CircularProgressIndicator())
        : billableReadings.isEmpty && _invoices.isEmpty
        ? const Center(
            child: Text('No hay recibos generados para este periodo.'),
          )
        : ListView.separated(
            itemCount: totalItems,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index < billableReadings.length) {
                final reading = billableReadings[index];
                return _BillableReadingCard(
                  reading: reading,
                  onGenerate: () => _generateInvoiceForReading(reading),
                );
              }
              final invoice = filteredInvoices[index - billableReadings.length];
              return _InvoicePreviewCard(
                invoice: invoice,
                onPrint: () => _printInvoice(invoice),
                onRegenerate: invoice.estaPagado
                    ? null
                    : () => _regenerateInvoice(invoice),
              );
            },
          );

    return LayoutBuilder(
      builder: (context, constraints) {
        final pageWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        return SizedBox(
          width: pageWidth,
          child: Stack(
            children: [
              AbsorbPointer(
                absorbing: _saving,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HeaderPanel(
                      periods: _periods,
                      selectedPeriod: _selectedPeriod,
                      billableCount: billableReadings.length,
                      invoiceCount: _invoices.length,
                      unpreparedCount: unpreparedReadings.length,
                      onPeriodChanged: (period) {
                        if (period != null) {
                          _loadPeriodData(period);
                        }
                      },
                      onGenerate: billableReadings.isEmpty || _saving
                          ? null
                          : _generateInvoices,
                      onRegenerate: _invoices.isEmpty || _saving
                          ? null
                          : _regenerateInvoices,
                      onExportPeriod: _invoices.isEmpty || _saving
                          ? null
                          : _exportPeriodInvoicesUnified,
                      onExportSector:
                          _invoices.isEmpty ||
                              availableSectors.isEmpty ||
                              _saving
                          ? null
                          : _exportSectorInvoicesUnified,
                      onShowUnprepared: unpreparedReadings.isEmpty
                          ? null
                          : _showUnpreparedReadings,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _searchController,
                      onChanged: (value) =>
                          setState(() => _search = value.trim()),
                      decoration: InputDecoration(
                        labelText: 'Buscar en facturacion',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _search.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _search = '');
                                },
                                tooltip: 'Limpiar busqueda',
                                icon: const Icon(Icons.close_rounded),
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _InvoiceSearchFieldSelector(
                      selected: _searchField,
                      onChanged: (value) =>
                          setState(() => _searchField = value),
                    ),
                    const SizedBox(height: 12),
                    if (availableSectors.isNotEmpty) ...[
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
                          ...availableSectors.map(
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
                    Expanded(child: invoicesList),
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
          ),
        );
      },
    );
  }
}
