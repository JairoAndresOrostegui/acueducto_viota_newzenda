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
  State<ConsumptionRegisterPage> createState() => _ConsumptionRegisterPageState();
}

class _ConsumptionRegisterPageState extends State<ConsumptionRegisterPage> {
  static const Set<String> _officialStates = {
    'sincronizado',
    'resuelto',
    'editado_admin',
    'ajuste_pendiente',
    'irregularidad_reportada',
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
  String _query = '';
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
    final periodReadings = _readings
        .where((item) => item.periodoActual == _workingPeriod)
        .toList();
    final compact = MediaQuery.sizeOf(context).width < 760;
    final pendingCount = periodReadings
        .where((item) => !item.isSynced && !item.isBlocked)
        .length;
    final blockedCount = periodReadings.where((item) => item.isBlocked).length;
    final irregularCount = periodReadings.where((item) => item.hasIrregularity).length;
    final customerList = filteredCustomers.isEmpty
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
            itemCount: filteredCustomers.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final customer = filteredCustomers[index];
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
                onRegister: _workingPeriod == null ||
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
                        onDownloadPeriod: _downloadWorkingPeriod,
                        onUploadReadings: _uploadPendingReadings,
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _searchController,
                        onChanged: (value) => setState(() => _query = value),
                        decoration: const InputDecoration(
                          labelText: 'Buscar por nombre, codigo de contador o codigo de usuario',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
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
                      onDownloadPeriod: _downloadWorkingPeriod,
                      onUploadReadings: _uploadPendingReadings,
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _searchController,
                      onChanged: (value) => setState(() => _query = value),
                      decoration: const InputDecoration(
                        labelText: 'Buscar por nombre, codigo de contador o codigo de usuario',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
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
    return _customers.where((item) => item.searchText.contains(query)).toList();
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
    final previous = _readings
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
        throw StateError(
          'Todavía hay lecturas locales pendientes por subir. Sube o resuelve primero el período de trabajo actual antes de descargar otro.',
        );
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
      final conflicts = <String>[];
      var syncedCount = 0;
      var omittedCount = 0;

      for (var index = 0; index < readings.length; index++) {
        final item = readings[index];
        if (item.isSynced || item.isBlocked) {
          continue;
        }

        final existing = await _firestoreService.fetchReading(
          period: item.periodoActual,
          meterCode: item.codigoContador,
        );

        if (existing != null && _officialStates.contains(existing.estado)) {
          final previous = await _firestoreService.fetchLatestPreviousReading(
            meterCode: item.codigoContador,
            currentPeriod: item.periodoActual,
          );
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

        final previous = await _firestoreService.fetchLatestPreviousReading(
          meterCode: item.codigoContador,
          currentPeriod: item.periodoActual,
        );
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
          estado: item.hasIrregularity ? 'irregularidad_reportada' : 'sincronizado',
          lecturaAnterior: previous?.lecturaActual,
          consumoCalculado: previous == null
              ? null
              : item.lecturaActual - previous.lecturaActual,
          conflictoId: null,
          detalleEstado: null,
        );
        await _firestoreService.saveReading(
          syncedReading,
          historyEntry: ConsumptionHistoryEntry(
            id: '${DateTime.now().microsecondsSinceEpoch}',
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

      await _localCacheService.saveReadings(readings);
      if (!mounted) {
        return;
      }
      setState(() => _readings = readings);

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

  List<ConsumptionCustomer> _buildCustomerCache(List<AppUser> users) {
    final items = <ConsumptionCustomer>[];
    for (final user in users) {
      for (final meter in user.numeroContador) {
        items.add(
          ConsumptionCustomer(
            codigoUsuario: user.codigoUsuario,
            codigoContador: meter,
            nombreUsuario: user.nombre,
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
      if (localItem != null && !localItem.isSynced && !localItem.isBlocked) {
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
        .where((item) => workingPeriod == null || item.periodoActual == workingPeriod)
        .where((item) => !item.isSynced && !item.isBlocked)
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

class _Header extends StatelessWidget {
  const _Header({
    required this.workingPeriod,
    required this.cachedClients,
    required this.pendingCount,
    required this.blockedCount,
    required this.irregularCount,
    required this.onDownloadPeriod,
    required this.onUploadReadings,
  });

  final String? workingPeriod;
  final int cachedClients;
  final int pendingCount;
  final int blockedCount;
  final int irregularCount;
  final VoidCallback onDownloadPeriod;
  final VoidCallback onUploadReadings;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final info = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Registrar consumos',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'El operador trabaja con un período descargado. Ese período no cambia automáticamente aunque el administrador marque otro como vigente.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Período de trabajo: ${workingPeriod ?? 'Sin descargar'} - Clientes: $cachedClients - Pendientes: $pendingCount - Bloqueados: $blockedCount - Irregularidades: $irregularCount',
            ),
          ],
        );

        final actions = Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            ElevatedButton.icon(
              onPressed: onDownloadPeriod,
              style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
              icon: const Icon(Icons.download_rounded),
              label: const Text('Descargar período vigente'),
            ),
            OutlinedButton.icon(
              onPressed: onUploadReadings,
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              icon: const Icon(Icons.cloud_upload_rounded),
              label: const Text('Subir lecturas'),
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
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: actions,
            ),
          ],
        );
      },
    );
  }
}

class _ConsumptionCustomerCard extends StatelessWidget {
  const _ConsumptionCustomerCard({
    required this.customer,
    required this.activePeriod,
    required this.reading,
    required this.previousReading,
    required this.onRegister,
  });

  final ConsumptionCustomer customer;
  final String? activePeriod;
  final ConsumptionReading? reading;
  final ConsumptionReading? previousReading;
  final VoidCallback? onRegister;

  @override
  Widget build(BuildContext context) {
    final blocked = reading?.isBlocked ?? false;
    final irregular = reading?.hasIrregularity ?? false;
    final statusColor = blocked
        ? Colors.orange.shade800
        : irregular
            ? Colors.red.shade800
            : AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: blocked
              ? Colors.orange.shade200
              : irregular
                  ? Colors.red.shade200
                  : AppColors.border,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final info = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                toDisplayUserName(customer.nombreUsuario),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text('Código usuario: ${customer.codigoUsuario} - Contador: ${customer.codigoContador}'),
              const SizedBox(height: 6),
              Text('Período de trabajo: ${activePeriod ?? 'Sin descargar'}'),
              const SizedBox(height: 6),
              Text(
                previousReading == null
                    ? 'Lectura anterior: sin histórico descargado'
                    : 'Lectura anterior: ${previousReading!.lecturaActual} (${previousReading!.periodoActual})',
              ),
              if (reading != null) ...[
                const SizedBox(height: 12),
                Text('Lectura actual: ${reading!.lecturaActual}'),
                if (reading!.consumoCalculado != null) ...[
                  const SizedBox(height: 4),
                  Text('Consumo calculado: ${reading!.consumoCalculado}'),
                ],
                const SizedBox(height: 4),
                Text(
                  'Estado: ${reading!.estado} - Operario: ${toDisplayUserName(reading!.nombreOperario)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: statusColor,
                  ),
                ),
                if ((reading!.observacionesOperario ?? '').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('Observación: ${reading!.observacionesOperario!}'),
                ],
                if (reading!.irregularidad != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Irregularidad: ${reading!.irregularidad!.tipo}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.red.shade800,
                    ),
                  ),
                ],
                if ((reading!.detalleEstado ?? '').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    reading!.detalleEstado!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: statusColor,
                    ),
                  ),
                ],
              ],
            ],
          );
          final action = ElevatedButton.icon(
            onPressed: onRegister,
            style: ElevatedButton.styleFrom(minimumSize: const Size(0, 44)),
            icon: Icon(
              reading == null ? Icons.edit_note_rounded : Icons.edit_rounded,
            ),
            label: Text(
              reading == null ? 'Registrar lectura' : 'Actualizar en dispositivo',
            ),
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

class _ReadingDialog extends StatefulWidget {
  const _ReadingDialog({
    required this.customer,
    required this.period,
    required this.currentUser,
    required this.previousReading,
    required this.existingReading,
  });

  final ConsumptionCustomer customer;
  final String period;
  final AppUser currentUser;
  final ConsumptionReading? previousReading;
  final ConsumptionReading? existingReading;

  @override
  State<_ReadingDialog> createState() => _ReadingDialogState();
}

class _ReadingDialogState extends State<_ReadingDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _readingController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  bool _reportIrregularity = false;
  String _irregularityType = 'contador_adulterado';

  @override
  void initState() {
    super.initState();
    final existing = widget.existingReading;
    if (existing != null) {
      _readingController.text = '${existing.lecturaActual}';
      _notesController.text = existing.observacionesOperario ?? '';
      _reportIrregularity = existing.irregularidad != null;
      _irregularityType = existing.irregularidad?.tipo ?? _irregularityType;
    }
  }

  @override
  void dispose() {
    _readingController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Registrar lectura',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 20),
                  Text('Período: ${widget.period}'),
                  const SizedBox(height: 8),
                  Text('Código usuario: ${widget.customer.codigoUsuario}'),
                  const SizedBox(height: 8),
                  Text('Código contador: ${widget.customer.codigoContador}'),
                  const SizedBox(height: 8),
                  Text('Usuario: ${toDisplayUserName(widget.customer.nombreUsuario)}'),
                  const SizedBox(height: 8),
                  Text(
                    widget.previousReading == null
                        ? 'Sin histórico previo descargado'
                        : 'Lectura anterior: ${widget.previousReading!.lecturaActual} (${widget.previousReading!.periodoActual})',
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _readingController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Lectura actual'),
                    validator: (value) {
                      final parsed = int.tryParse(value?.trim() ?? '');
                      if (parsed == null) {
                        return 'Ingresa una lectura válida.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    value: _reportIrregularity,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Reportar irregularidad'),
                    subtitle: const Text(
                      'Úsalo cuando el contador esté dañado, adulterado o la lectura no sea confiable.',
                    ),
                    onChanged: (value) {
                      setState(() => _reportIrregularity = value);
                    },
                  ),
                  if (_reportIrregularity) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _irregularityType,
                      decoration: const InputDecoration(
                        labelText: 'Tipo de irregularidad',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'contador_adulterado',
                          child: Text('Contador adulterado'),
                        ),
                        DropdownMenuItem(
                          value: 'contador_danado',
                          child: Text('Contador dañado'),
                        ),
                        DropdownMenuItem(
                          value: 'lectura_menor_sospechosa',
                          child: Text('Lectura menor sospechosa'),
                        ),
                        DropdownMenuItem(
                          value: 'contador_inaccesible',
                          child: Text('Contador inaccesible'),
                        ),
                        DropdownMenuItem(
                          value: 'sin_lectura_visible',
                          child: Text('Sin lectura visible'),
                        ),
                        DropdownMenuItem(
                          value: 'fuga_o_anomalia',
                          child: Text('Fuga o anomalía'),
                        ),
                        DropdownMenuItem(
                          value: 'otro',
                          child: Text('Otro'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _irregularityType = value);
                        }
                      },
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _notesController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: _reportIrregularity
                          ? 'Observaciones de irregularidad'
                          : 'Observaciones',
                    ),
                    validator: (value) {
                      if (_reportIrregularity && (value?.trim().isEmpty ?? true)) {
                        return 'Describe la irregularidad.';
                      }
                      return null;
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
                      ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                        ),
                        child: const Text('Guardar en dispositivo'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final now = DateTime.now();
    final previousValue = widget.previousReading?.lecturaActual;
    final currentValue = int.parse(_readingController.text.trim());
    final irregularity = !_reportIrregularity
        ? null
        : ConsumptionIrregularity(
            tipo: _irregularityType,
            descripcion: _notesController.text.trim(),
            reportadoPorUid: widget.currentUser.uid,
            reportadoPorNombre: widget.currentUser.nombre,
            fechaReporte: now,
            lecturaObservada: currentValue,
          );

    Navigator.of(context).pop(
      ConsumptionReading(
        id: '${widget.period}|${widget.customer.codigoContador}',
        codigoUsuario: widget.customer.codigoUsuario,
        codigoContador: widget.customer.codigoContador,
        nombreUsuario: widget.customer.nombreUsuario,
        lecturaActual: currentValue,
        periodoActual: widget.period,
        fecha: now,
        nombreOperario: widget.currentUser.nombre,
        actorUid: widget.currentUser.uid,
        estado: _reportIrregularity ? 'pendiente_revision' : 'pendiente_local',
        lecturaAnterior: previousValue,
        consumoCalculado:
            previousValue == null ? null : currentValue - previousValue,
        facturado: widget.existingReading?.facturado ?? false,
        pagado: widget.existingReading?.pagado ?? false,
        observacionesOperario: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        observacionesAdmin: widget.existingReading?.observacionesAdmin,
        reciboId: widget.existingReading?.reciboId,
        irregularidad: irregularity,
        conflictoId: null,
        detalleEstado: null,
      ),
    );
  }
}
