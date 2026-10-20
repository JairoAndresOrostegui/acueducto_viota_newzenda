import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/presentation/text_formatters.dart';
import '../../../../theme/app_colors.dart';
import '../../../billing/periods/data/billing_period_firestore_service.dart';
import '../../../consumptions/data/consumption_conflict_firestore_service.dart';
import '../../../consumptions/data/consumption_firestore_service.dart';
import '../../../consumptions/data/consumption_local_cache_service.dart';
import '../../../consumptions/domain/consumption_customer.dart';
import '../../../consumptions/domain/consumption_history_entry.dart';
import '../../../consumptions/domain/consumption_irregularity.dart';
import '../../../consumptions/domain/consumption_reading.dart';
import '../../../users/data/user_firestore_service.dart';
import '../../../users/domain/app_user.dart';

part 'consumption_register_page_components.dart';

class ConsumptionRegisterPage extends StatefulWidget {
  const ConsumptionRegisterPage({
    super.key,
    required this.currentUser,
    this.userService,
    this.periodService,
    this.firestoreService,
    this.conflictService,
    this.localCacheService,
  });

  final AppUser currentUser;
  final UserFirestoreService? userService;
  final BillingPeriodFirestoreService? periodService;
  final ConsumptionFirestoreService? firestoreService;
  final ConsumptionConflictFirestoreService? conflictService;
  final ConsumptionLocalCacheService? localCacheService;

  @override
  State<ConsumptionRegisterPage> createState() =>
      _ConsumptionRegisterPageState();
}

class _ConsumptionRegisterPageState extends State<ConsumptionRegisterPage> {
  static const Set<String> _officialStates = {
    'sincronizado',
    'resuelto',
    'editado_admin',
    'ajuste_pendiente',
    'irregularidad_reportada',
    'facturado',
    'pagado',
    'suspendido',
  };

  late final UserFirestoreService _userService =
      widget.userService ?? UserFirestoreService();
  late final BillingPeriodFirestoreService _periodService =
      widget.periodService ?? BillingPeriodFirestoreService();
  late final ConsumptionFirestoreService _firestoreService =
      widget.firestoreService ?? ConsumptionFirestoreService();
  late final ConsumptionConflictFirestoreService _conflictService =
      widget.conflictService ?? ConsumptionConflictFirestoreService();
  late final ConsumptionLocalCacheService _localCacheService =
      widget.localCacheService ?? ConsumptionLocalCacheService();

  final TextEditingController _searchController = TextEditingController();

  bool _isBusy = false;
  bool _showPendingReadings = false;
  bool _showIrregularReadings = false;
  bool _hasLocalEditsThisSession = false;
  String _query = '';
  String _searchField = 'nombre';
  String? _workingPeriod;
  List<ConsumptionCustomer> _customers = const [];
  List<ConsumptionReading> _readings = const [];

  @override
  void initState() {
    super.initState();
    _loadLocalState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredCustomers = _filteredCustomers();
    final filteredPendingCustomers = _filteredPendingCustomers();
    final filteredIrregularCustomers = _filteredIrregularCustomers();
    final periodReadings = _readings
        .where((item) => item.periodoActual == _workingPeriod)
        .toList();
    final compact = MediaQuery.sizeOf(context).width < 760;
    final pendingCount = periodReadings
        .where((item) => item.isPendingUpload)
        .length;
    final blockedCount = periodReadings.where((item) => item.isBlocked).length;
    final irregularCount = periodReadings
        .where((item) => item.hasIrregularity)
        .length;
    final missingReadingsCount = _pendingCustomersWithoutReading().length;
    final visibleCustomers = _showPendingReadings
        ? filteredPendingCustomers
        : _showIrregularReadings
        ? filteredIrregularCustomers
        : filteredCustomers;
    final listIsEmpty = visibleCustomers.isEmpty;
    final customerList = listIsEmpty
        ? const Center(
            child: Text(
              'No hay clientes descargados o no coinciden con la busqueda.',
            ),
          )
        : ListView.separated(
            shrinkWrap: compact,
            physics: compact
                ? const NeverScrollableScrollPhysics()
                : const AlwaysScrollableScrollPhysics(),
            itemCount: visibleCustomers.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (_showPendingReadings) {
                final customer = visibleCustomers[index];
                return _PendingReadingRow(
                  customer: customer,
                  previousReading: _previousReadingFor(
                    customer.codigoContador,
                    beforePeriod: _workingPeriod,
                  ),
                );
              }
              final customer = visibleCustomers[index];
              final reading = _readingFor(
                customer.codigoContador,
                _workingPeriod,
              );
              final previousReading = _previousReadingFor(
                customer.codigoContador,
                beforePeriod: _workingPeriod,
              );
              return _ConsumptionCustomerCard(
                customer: customer,
                activePeriod: _workingPeriod,
                reading: reading,
                previousReading: previousReading,
                onRegister:
                    _workingPeriod == null ||
                        reading?.facturado == true ||
                        reading?.pagado == true
                    ? null
                    : () => _openRegisterDialog(customer),
              );
            },
          );

    return Stack(
      children: [
        AbsorbPointer(
          absorbing: _isBusy,
          child: compact
              ? SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Header(
                        workingPeriod: _workingPeriod,
                        cachedClients: _customers.length,
                        pendingCount: pendingCount,
                        blockedCount: blockedCount,
                        irregularCount: irregularCount,
                        missingReadingsCount: missingReadingsCount,
                        showPendingReadings: _showPendingReadings,
                        showIrregularReadings: _showIrregularReadings,
                        onDownloadPeriod: _downloadWorkingPeriod,
                        onUploadReadings: _uploadPendingReadings,
                        onClearLocalReadings: _clearLocalReadings,
                        onTogglePendingReadings: _togglePendingReadings,
                        onToggleIrregularReadings: _toggleIrregularReadings,
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _searchController,
                        onChanged: (value) => setState(() => _query = value),
                        decoration: const InputDecoration(
                          labelText: 'Buscar en consumos',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _ReadingSearchFieldSelector(
                        selected: _searchField,
                        onChanged: (value) =>
                            setState(() => _searchField = value),
                      ),
                      const SizedBox(height: 16),
                      customerList,
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Header(
                      workingPeriod: _workingPeriod,
                      cachedClients: _customers.length,
                      pendingCount: pendingCount,
                      blockedCount: blockedCount,
                      irregularCount: irregularCount,
                      missingReadingsCount: missingReadingsCount,
                      showPendingReadings: _showPendingReadings,
                      showIrregularReadings: _showIrregularReadings,
                      onDownloadPeriod: _downloadWorkingPeriod,
                      onUploadReadings: _uploadPendingReadings,
                      onClearLocalReadings: _clearLocalReadings,
                      onTogglePendingReadings: _togglePendingReadings,
                      onToggleIrregularReadings: _toggleIrregularReadings,
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _searchController,
                      onChanged: (value) => setState(() => _query = value),
                      decoration: const InputDecoration(
                        labelText: 'Buscar en consumos',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _ReadingSearchFieldSelector(
                      selected: _searchField,
                      onChanged: (value) =>
                          setState(() => _searchField = value),
                    ),
                    const SizedBox(height: 16),
                    Expanded(child: customerList),
                  ],
                ),
        ),
        if (_isBusy)
          Positioned.fill(
            child: ColoredBox(
              color: AppColors.textPrimary.withValues(alpha: 0.18),
              child: const Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }

  Future<void> _loadLocalState() async {
    final period = await _localCacheService.loadActivePeriod();
    final customers = await _localCacheService.loadCustomers();
    final readings = await _localCacheService.loadReadings();
    if (!mounted) {
      return;
    }
    setState(() {
      _workingPeriod = period;
      _customers = customers;
      _readings = readings;
    });
  }

  List<ConsumptionCustomer> _filteredCustomers() {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) {
      return _customers;
    }
    return _customers.where((item) => _matchesSearch(item, query)).toList();
  }

  List<ConsumptionCustomer> _filteredPendingCustomers() {
    final pending = _pendingCustomersWithoutReading();
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) {
      return pending;
    }
    return pending.where((item) => _matchesSearch(item, query)).toList();
  }

  List<ConsumptionCustomer> _filteredIrregularCustomers() {
    final period = _workingPeriod;
    if (period == null) {
      return const [];
    }
    final irregularMeters = _readings
        .where((item) => item.periodoActual == period && item.hasIrregularity)
        .map((item) => item.codigoContador)
        .toSet();
    final items = _customers
        .where((customer) => irregularMeters.contains(customer.codigoContador))
        .toList();
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) {
      return items;
    }
    return items.where((item) => _matchesSearch(item, query)).toList();
  }

  bool _matchesSearch(ConsumptionCustomer item, String query) {
    return switch (_searchField) {
      'codigoUsuario' => item.codigoUsuario.toLowerCase().contains(query),
      'contador' => item.codigoContador.toLowerCase().contains(query),
      _ => item.nombreUsuario.toLowerCase().contains(query),
    };
  }

  List<ConsumptionCustomer> _pendingCustomersWithoutReading() {
    final period = _workingPeriod;
    if (period == null) {
      return const [];
    }
    return _customers
        .where(
          (customer) => _readingFor(customer.codigoContador, period) == null,
        )
        .toList();
  }

  void _togglePendingReadings() {
    if (_workingPeriod == null) {
      _showInfoDialog(
        title: 'Sin periodo de trabajo',
        message:
            'Descarga primero el periodo vigente para revisar lecturas pendientes.',
      );
      return;
    }
    setState(() {
      _showPendingReadings = !_showPendingReadings;
      if (_showPendingReadings) {
        _showIrregularReadings = false;
      }
    });
  }

  void _toggleIrregularReadings() {
    if (_workingPeriod == null) {
      _showInfoDialog(
        title: 'Sin periodo de trabajo',
        message:
            'Descarga primero el periodo vigente para revisar irregularidades.',
      );
      return;
    }
    setState(() {
      _showIrregularReadings = !_showIrregularReadings;
      if (_showIrregularReadings) {
        _showPendingReadings = false;
      }
    });
  }

  ConsumptionReading? _readingFor(String meterCode, String? period) {
    if (period == null) {
      return null;
    }
    for (final item in _readings) {
      if (item.codigoContador == meterCode && item.periodoActual == period) {
        return item;
      }
    }
    return null;
  }

  ConsumptionReading? _previousReadingFor(
    String meterCode, {
    required String? beforePeriod,
  }) {
    if (beforePeriod == null) {
      return null;
    }
    final previous =
        _readings
            .where((item) => item.codigoContador == meterCode)
            .where((item) => item.periodoActual.compareTo(beforePeriod) < 0)
            .toList()
          ..sort((a, b) => b.periodoActual.compareTo(a.periodoActual));
    return previous.isEmpty ? null : previous.first;
  }

  Future<void> _downloadWorkingPeriod() async {
    setState(() => _isBusy = true);
    try {
      final pendingLocal = _uploadableReadingsForWorkingPeriod();
      if (pendingLocal.isNotEmpty) {
        if (!_hasLocalEditsThisSession) {
          await _localCacheService.clearReadings();
          if (!mounted) {
            return;
          }
          setState(() {
            _readings = [
              for (final item in _readings)
                if (!item.isPendingUpload) item,
            ];
          });
        } else {
          throw StateError(
            'Todavía hay lecturas locales pendientes por subir. Sube o resuelve primero el período de trabajo actual antes de descargar otro.',
          );
        }
      }

      final activePeriod = await _periodService.fetchActivePeriod();
      if (activePeriod == null) {
        throw StateError('No hay período vigente configurado en el sistema.');
      }

      final clients = await _userService.fetchActiveClients();
      final periods = await _periodService.fetchPeriods();
      final historicalReadings = <ConsumptionReading>[];
      for (final period in periods) {
        if (period.clave.compareTo(activePeriod.clave) > 0) {
          continue;
        }
        final periodReadings = await _firestoreService.fetchReadingsForPeriod(
          period.clave,
        );
        historicalReadings.addAll(periodReadings);
      }
      final customerCache = _buildCustomerCache(clients);
      final mergedReadings = _mergeReadings(
        local: _readings,
        remote: historicalReadings,
      );

      await _localCacheService.saveActivePeriod(activePeriod.clave);
      await _localCacheService.saveCustomers(customerCache);
      await _localCacheService.saveReadings(mergedReadings);

      if (!mounted) {
        return;
      }
      setState(() {
        _workingPeriod = activePeriod.clave;
        _customers = customerCache;
        _readings = mergedReadings;
        _showPendingReadings = false;
        _showIrregularReadings = false;
        _hasLocalEditsThisSession = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Período ${activePeriod.clave} descargado al dispositivo.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      await _showInfoDialog(
        title: 'No fue posible descargar el período',
        message: '$error',
      );
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _uploadPendingReadings() async {
    setState(() => _isBusy = true);
    try {
      final readings = [...await _localCacheService.loadReadings()];
      final pendingIndexes = <int>[];
      for (var index = 0; index < readings.length; index++) {
        final item = readings[index];
        if (item.isPendingUpload) {
          pendingIndexes.add(index);
        }
      }
      if (pendingIndexes.isEmpty) {
        await _localCacheService.saveReadings(readings);
        if (!mounted) {
          return;
        }
        setState(() => _readings = readings);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No habia lecturas pendientes por subir.'),
          ),
        );
        return;
      }

      final periods = pendingIndexes
          .map((index) => readings[index].periodoActual)
          .where((period) => period.trim().isNotEmpty)
          .toSet();
      final existingByKey = <String, ConsumptionReading>{};
      final previousByPeriod = <String, Map<String, ConsumptionReading>>{};
      for (final period in periods) {
        final periodReadings = await _firestoreService.fetchReadingsForPeriod(
          period,
        );
        for (final reading in periodReadings) {
          existingByKey['$period|${reading.codigoContador}'] = reading;
        }
        final meterCodes = pendingIndexes
            .map((index) => readings[index])
            .where((item) => item.periodoActual == period)
            .map((item) => item.codigoContador);
        previousByPeriod[period] = await _firestoreService
            .fetchLatestPreviousReadingsByMeter(
              meterCodes: meterCodes,
              currentPeriod: period,
            );
      }

      final conflicts = <String>[];
      final readingsToSync = <ConsumptionReading>[];
      final historyEntries = <ConsumptionHistoryEntry?>[];
      var syncedCount = 0;
      var omittedCount = 0;

      for (final index in pendingIndexes) {
        final item = readings[index];
        final existing =
            existingByKey['${item.periodoActual}|${item.codigoContador}'];
        final previous =
            previousByPeriod[item.periodoActual]?[item.codigoContador];

        if (existing != null && _officialStates.contains(existing.estado)) {
          final message =
              'Ya existe una lectura oficial para ${item.codigoContador} en ${item.periodoActual}.';
          final conflictId = await _conflictService.registerConflict(
            proposedReading: item,
            existingReading: existing,
            previousReading: previous,
            motivo: 'lectura_existente',
            mensaje: message,
          );
          readings[index] = item.copyWith(
            estado: 'bloqueado',
            conflictoId: conflictId,
            detalleEstado: message,
          );
          conflicts.add(
            '${item.periodoActual} - ${item.codigoContador} - ${toDisplayUserName(item.nombreUsuario)}',
          );
          continue;
        }

        if (previous != null && item.lecturaActual < previous.lecturaActual) {
          final message =
              'La lectura ${item.lecturaActual} es menor que la anterior oficial (${previous.lecturaActual}).';
          final conflictId = await _conflictService.registerConflict(
            proposedReading: item,
            existingReading: existing,
            previousReading: previous,
            motivo: 'lectura_menor',
            mensaje: message,
          );
          readings[index] = item.copyWith(
            estado: 'bloqueado',
            conflictoId: conflictId,
            detalleEstado: message,
          );
          conflicts.add(
            '${item.periodoActual} - ${item.codigoContador} - ${toDisplayUserName(item.nombreUsuario)}',
          );
          continue;
        }

        if (existing != null && existing.isSynced && item.isSynced) {
          omittedCount++;
          continue;
        }

        final syncedReading = item.copyWith(
          estado: item.hasIrregularity
              ? 'irregularidad_reportada'
              : 'sincronizado',
          lecturaAnterior: previous?.lecturaActual,
          consumoCalculado: previous == null
              ? null
              : item.lecturaActual - previous.lecturaActual,
          conflictoId: null,
          detalleEstado: null,
        );
        readingsToSync.add(syncedReading);
        historyEntries.add(
          ConsumptionHistoryEntry(
            id: '${DateTime.now().microsecondsSinceEpoch}_$index',
            tipoEvento: item.hasIrregularity
                ? 'irregularidad_reportada'
                : 'captura_sincronizada',
            actorUid: widget.currentUser.uid,
            actorNombre: widget.currentUser.nombre,
            actorRol: widget.currentUser.rol,
            fecha: DateTime.now(),
            estadoAnterior: item.estado,
            estadoNuevo: syncedReading.estado,
            valorAnterior: item.lecturaAnterior,
            valorNuevo: syncedReading.lecturaActual,
            observaciones: item.observacionesOperario,
          ),
        );
        readings[index] = syncedReading;
        syncedCount++;
      }

      await _firestoreService.saveReadingsBatch(
        readings: readingsToSync,
        historyEntries: historyEntries,
      );
      await _localCacheService.saveReadings(readings);
      if (!mounted) {
        return;
      }
      setState(() => _readings = readings);
      _hasLocalEditsThisSession = false;

      if (conflicts.isNotEmpty) {
        await _showInfoDialog(
          title: 'Sincronizacion con conflictos',
          message:
              'Lecturas subidas: $syncedCount. Omitidas: $omittedCount.\n\nConflictos:\n${conflicts.join('\n')}',
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              syncedCount == 0
                  ? 'No habia lecturas pendientes por subir.'
                  : 'Sincronizacion completada. Lecturas subidas: $syncedCount. Omitidas: $omittedCount.',
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      await _showInfoDialog(
        title: 'No fue posible subir lecturas',
        message: '$error',
      );
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _clearLocalReadings() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Borrar lecturas locales'),
        content: const Text(
          'Esto elimina solo las lecturas guardadas en este dispositivo o navegador. No borra usuarios ni el periodo descargado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    setState(() => _isBusy = true);
    try {
      await _localCacheService.clearReadings();
      if (!mounted) {
        return;
      }
      setState(() {
        _readings = [
          for (final item in _readings)
            if (!item.isPendingUpload) item,
        ];
        _showPendingReadings = false;
        _showIrregularReadings = false;
        _hasLocalEditsThisSession = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lecturas locales borradas.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  List<ConsumptionCustomer> _buildCustomerCache(List<AppUser> users) {
    final items = <ConsumptionCustomer>[];
    for (final user in users) {
      for (final code in user.codigosUsuario) {
        items.add(
          ConsumptionCustomer(
            codigoUsuario: code.codigoUsuario,
            codigoContador: code.numeroContador,
            nombreUsuario: user.nombre,
            sector: code.sector,
          ),
        );
      }
    }
    items.sort((a, b) {
      final userCompare = a.nombreUsuario.compareTo(b.nombreUsuario);
      if (userCompare != 0) {
        return userCompare;
      }
      return a.codigoContador.compareTo(b.codigoContador);
    });
    return items;
  }

  List<ConsumptionReading> _mergeReadings({
    required List<ConsumptionReading> local,
    required List<ConsumptionReading> remote,
  }) {
    final merged = <String, ConsumptionReading>{};
    for (final item in local) {
      merged[item.id] = item;
    }
    for (final item in remote) {
      final localItem = merged[item.id];
      if (localItem != null && localItem.isPendingUpload) {
        continue;
      }
      merged[item.id] = item;
    }
    final values = merged.values.toList()
      ..sort((a, b) => b.fecha.compareTo(a.fecha));
    return values;
  }

  List<ConsumptionReading> _uploadableReadingsForWorkingPeriod() {
    final workingPeriod = _workingPeriod;
    return _readings
        .where(
          (item) =>
              workingPeriod == null || item.periodoActual == workingPeriod,
        )
        .where((item) => item.isPendingUpload)
        .toList();
  }

  Future<void> _openRegisterDialog(ConsumptionCustomer customer) async {
    final period = _workingPeriod;
    if (period == null) {
      return;
    }

    final reading = await showDialog<ConsumptionReading>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ReadingDialog(
        customer: customer,
        period: period,
        currentUser: widget.currentUser,
        previousReading: _previousReadingFor(
          customer.codigoContador,
          beforePeriod: period,
        ),
        existingReading: _readingFor(customer.codigoContador, period),
      ),
    );

    if (reading == null) {
      return;
    }

    final readings = await _localCacheService.loadReadings();
    final updatedMap = <String, ConsumptionReading>{
      for (final item in readings) item.id: item,
    };
    updatedMap[reading.id] = reading;
    final updated = updatedMap.values.toList()
      ..sort((a, b) => b.fecha.compareTo(a.fecha));
    await _localCacheService.saveReadings(updated);
    if (!mounted) {
      return;
    }
    setState(() => _readings = updated);
    _hasLocalEditsThisSession = true;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Lectura guardada en el dispositivo.')),
    );
  }

  Future<void> _showInfoDialog({
    required String title,
    required String message,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }
}

String _displaySector(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty || normalized.toLowerCase() == 'na') {
    return 'Sin sector';
  }
  return toDisplayText(normalized);
}
