import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/presentation/text_formatters.dart';
import '../../../../theme/app_colors.dart';
import '../../../billing/periods/data/billing_period_firestore_service.dart';
import '../../../consumptions/data/consumption_conflict_firestore_service.dart';
import '../../../consumptions/data/consumption_firestore_service.dart';
import '../../../consumptions/data/consumption_local_cache_service.dart';
import '../../../consumptions/domain/consumption_customer.dart';
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
  String? _activePeriod;
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
    final pendingCount = _readings
        .where((item) => !item.isSynced && !item.isBlocked)
        .length;
    final blockedCount = _readings.where((item) => item.isBlocked).length;

    return Stack(
      children: [
        AbsorbPointer(
          absorbing: _isBusy,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(
                activePeriod: _activePeriod,
                cachedClients: _customers.length,
                pendingCount: pendingCount,
                blockedCount: blockedCount,
                onSync: _syncAll,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                decoration: const InputDecoration(
                  labelText: 'Buscar por codigo de contador o codigo de usuario',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: filteredCustomers.isEmpty
                    ? const Center(
                        child: Text(
                          'No hay clientes sincronizados o no coinciden con la busqueda.',
                        ),
                      )
                    : ListView.separated(
                        itemCount: filteredCustomers.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final customer = filteredCustomers[index];
                          final reading = _readingFor(customer.codigoContador);
                          return _ConsumptionCustomerCard(
                            customer: customer,
                            activePeriod: _activePeriod,
                            reading: reading,
                            onRegister: _activePeriod == null || reading != null
                                ? null
                                : () => _openRegisterDialog(customer),
                          );
                        },
                      ),
              ),
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
      _activePeriod = period;
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

  ConsumptionReading? _readingFor(String meterCode) {
    final period = _activePeriod;
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
    String? beforePeriod,
  }) {
    final period = beforePeriod ?? _activePeriod;
    if (period == null) {
      return null;
    }
    final previous = _readings
        .where((item) => item.codigoContador == meterCode)
        .where((item) => item.periodoActual.compareTo(period) < 0)
        .toList()
      ..sort((a, b) => b.periodoActual.compareTo(a.periodoActual));
    return previous.isEmpty ? null : previous.first;
  }

  Future<void> _syncAll() async {
    setState(() => _isBusy = true);
    try {
      var readings = await _localCacheService.loadReadings();
      final unresolvedBlocked = <String, bool>{};
      var syncedCount = 0;
      var blockedCount = 0;
      var carriedBlockedCount = 0;

      for (var index = 0; index < readings.length; index++) {
        final item = readings[index];
        if (item.isSynced) {
          continue;
        }

        if (item.isBlocked) {
          final unresolved = await _isConflictStillPending(item);
          unresolvedBlocked[item.id] = unresolved;
          if (unresolved) {
            carriedBlockedCount++;
          }
          continue;
        }

        final existing = await _firestoreService.fetchReadingById(item.id);
        if (existing != null) {
          final previous = await _firestoreService.fetchLatestPreviousReading(
            meterCode: item.codigoContador,
            currentPeriod: item.periodoActual,
          );
          final message =
              'Ya existe una lectura sincronizada para este contador en el periodo ${item.periodoActual}. Quedo bloqueada hasta que un administrador defina el valor oficial.';
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
          unresolvedBlocked[item.id] = true;
          blockedCount++;
          continue;
        }

        final previous = await _firestoreService.fetchLatestPreviousReading(
          meterCode: item.codigoContador,
          currentPeriod: item.periodoActual,
        );
        if (previous != null && item.lecturaActual < previous.lecturaActual) {
          final message =
              'La lectura ${item.lecturaActual} es menor que la ultima lectura registrada (${previous.lecturaActual}). Quedo bloqueada para revision administrativa.';
          final conflictId = await _conflictService.registerConflict(
            proposedReading: item,
            previousReading: previous,
            motivo: 'lectura_menor',
            mensaje: message,
          );
          readings[index] = item.copyWith(
            estado: 'bloqueado',
            conflictoId: conflictId,
            detalleEstado: message,
          );
          unresolvedBlocked[item.id] = true;
          blockedCount++;
          continue;
        }

        await _firestoreService.saveReading(
          item.copyWith(
            estado: 'sincronizado',
            conflictoId: null,
            detalleEstado: null,
          ),
        );
        readings[index] = item.copyWith(
          estado: 'sincronizado',
          conflictoId: null,
          detalleEstado: null,
        );
        unresolvedBlocked[item.id] = false;
        syncedCount++;
      }

      final activePeriod = await _periodService.fetchActivePeriod();
      final clients = await _userService.fetchActiveClients();
      final customerCache = _buildCustomerCache(clients);

      if (activePeriod != null) {
        final remoteReadings = await _firestoreService.fetchReadingsForPeriod(
          activePeriod.clave,
        );
        readings = _mergeReadings(
          local: readings,
          remote: remoteReadings,
          unresolvedBlocked: unresolvedBlocked,
        );
        await _localCacheService.saveActivePeriod(activePeriod.clave);
      }

      await _localCacheService.saveCustomers(customerCache);
      await _localCacheService.saveReadings(readings);

      if (!mounted) {
        return;
      }
      setState(() {
        _activePeriod = activePeriod?.clave;
        _customers = customerCache;
        _readings = readings;
      });

      if (blockedCount > 0 || carriedBlockedCount > 0) {
        await _showInfoDialog(
          title: 'Sincronizacion con conflictos',
          message:
              'Se sincronizaron $syncedCount lecturas. Nuevos bloqueos: $blockedCount. Bloqueos pendientes: $carriedBlockedCount. Un administrador debe resolverlos antes de que ese contador vuelva a quedar en estado satisfactorio.',
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              syncedCount == 0
                  ? 'No habia lecturas pendientes por sincronizar.'
                  : 'Sincronizacion completada. Lecturas subidas: $syncedCount.',
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      await _showInfoDialog(
        title: 'No fue posible sincronizar',
        message: '$error',
      );
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<bool> _isConflictStillPending(ConsumptionReading reading) async {
    final conflictId = reading.conflictoId;
    if (conflictId == null || conflictId.isEmpty) {
      return true;
    }
    final conflict = await _conflictService.fetchConflictById(conflictId);
    return conflict == null || !conflict.isResolved;
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
    items.sort((a, b) => a.nombreUsuario.compareTo(b.nombreUsuario));
    return items;
  }

  List<ConsumptionReading> _mergeReadings({
    required List<ConsumptionReading> local,
    required List<ConsumptionReading> remote,
    required Map<String, bool> unresolvedBlocked,
  }) {
    final merged = <String, ConsumptionReading>{};
    for (final item in local) {
      merged[item.id] = item;
    }
    for (final item in remote) {
      final localItem = merged[item.id];
      final keepBlocked =
          localItem != null &&
          localItem.isBlocked &&
          (unresolvedBlocked[item.id] ?? true);
      if (keepBlocked) {
        continue;
      }
      merged[item.id] = item.copyWith(
        estado: 'sincronizado',
        conflictoId: null,
        detalleEstado: null,
      );
    }
    final values = merged.values.toList()
      ..sort((a, b) => b.fecha.compareTo(a.fecha));
    return values;
  }

  Future<void> _openRegisterDialog(ConsumptionCustomer customer) async {
    final period = _activePeriod;
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
      const SnackBar(
        content: Text('Lectura guardada en el dispositivo.'),
      ),
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
    required this.activePeriod,
    required this.cachedClients,
    required this.pendingCount,
    required this.blockedCount,
    required this.onSync,
  });

  final String? activePeriod;
  final int cachedClients;
  final int pendingCount;
  final int blockedCount;
  final VoidCallback onSync;

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
              'Sincroniza el periodo vigente y la lista de clientes para capturar lecturas sin conexion y luego subirlas al sistema.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Periodo vigente: ${activePeriod ?? 'Sin sincronizar'} - Clientes cacheados: $cachedClients - Pendientes: $pendingCount - Bloqueados: $blockedCount',
            ),
          ],
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              info,
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onSync,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                ),
                icon: const Icon(Icons.sync_rounded),
                label: const Text('Sincronizar'),
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: info),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              onPressed: onSync,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 48),
              ),
              icon: const Icon(Icons.sync_rounded),
              label: const Text('Sincronizar'),
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
    required this.onRegister,
  });

  final ConsumptionCustomer customer;
  final String? activePeriod;
  final ConsumptionReading? reading;
  final VoidCallback? onRegister;

  @override
  Widget build(BuildContext context) {
    final blocked = reading?.isBlocked ?? false;
    final statusColor = blocked
        ? Colors.orange.shade800
        : AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: blocked ? Colors.orange.shade200 : AppColors.border,
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
              Text(
                'Codigo usuario: ${customer.codigoUsuario} - Contador: ${customer.codigoContador}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'Periodo: ${activePeriod ?? 'Sin sincronizar'}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (reading != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Lectura actual: ${reading!.lecturaActual}',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Estado: ${reading!.estado} - Operario: ${toDisplayUserName(reading!.nombreOperario)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: statusColor,
                  ),
                ),
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
          final action = reading == null
              ? ElevatedButton.icon(
                  onPressed: onRegister,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                  ),
                  icon: const Icon(Icons.edit_note_rounded),
                  label: const Text('Registrar lectura'),
                )
              : OutlinedButton.icon(
                  onPressed: null,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                  ),
                  icon: Icon(
                    blocked
                        ? Icons.lock_clock_rounded
                        : Icons.visibility_rounded,
                  ),
                  label: Text(
                    blocked ? 'Conflicto pendiente' : 'Lectura tomada',
                  ),
                );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                info,
                const SizedBox(height: 16),
                action,
              ],
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
  });

  final ConsumptionCustomer customer;
  final String period;
  final AppUser currentUser;
  final ConsumptionReading? previousReading;

  @override
  State<_ReadingDialog> createState() => _ReadingDialogState();
}

class _ReadingDialogState extends State<_ReadingDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _readingController = TextEditingController();

  @override
  void dispose() {
    _readingController.dispose();
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
                  Text('Periodo: ${widget.period}'),
                  const SizedBox(height: 8),
                  Text('Codigo usuario: ${widget.customer.codigoUsuario}'),
                  const SizedBox(height: 8),
                  Text('Codigo contador: ${widget.customer.codigoContador}'),
                  const SizedBox(height: 8),
                  Text(
                    'Usuario: ${toDisplayUserName(widget.customer.nombreUsuario)}',
                  ),
                  if (widget.previousReading != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Ultima lectura registrada: ${widget.previousReading!.lecturaActual} (${widget.previousReading!.periodoActual})',
                    ),
                  ],
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _readingController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Lectura actual',
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) {
                        return 'Campo obligatorio.';
                      }
                      final parsed = int.tryParse(text);
                      if (parsed == null) {
                        return 'Solo se permiten numeros.';
                      }
                      final previous = widget.previousReading;
                      if (previous != null && parsed < previous.lecturaActual) {
                        return 'La lectura no puede ser menor que ${previous.lecturaActual}.';
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
    final reading = ConsumptionReading(
      id: '${widget.period}|${widget.customer.codigoContador}',
      codigoUsuario: widget.customer.codigoUsuario,
      codigoContador: widget.customer.codigoContador,
      nombreUsuario: widget.customer.nombreUsuario,
      lecturaActual: int.parse(_readingController.text.trim()),
      periodoActual: widget.period,
      fecha: now,
      nombreOperario: widget.currentUser.nombre,
      actorUid: widget.currentUser.uid,
      estado: 'pendiente',
    );

    Navigator.of(context).pop(reading);
  }
}
