import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/presentation/text_formatters.dart';
import '../../../../theme/app_colors.dart';
import '../../../billing/periods/data/billing_period_firestore_service.dart';
import '../../../billing/periods/domain/billing_period.dart';
import '../../../billing/values/data/billing_value_config_firestore_service.dart';
import '../../../billing/values/domain/billing_value_config.dart';
import '../../../users/data/user_firestore_service.dart';
import '../../../users/domain/app_user.dart';

part 'extraordinary_values_page_components.dart';

class ExtraordinaryValuesPage extends StatefulWidget {
  const ExtraordinaryValuesPage({
    super.key,
    required this.currentUser,
    this.service,
    this.periodService,
    this.userService,
  });

  final AppUser currentUser;
  final BillingValueConfigFirestoreService? service;
  final BillingPeriodFirestoreService? periodService;
  final UserFirestoreService? userService;

  @override
  State<ExtraordinaryValuesPage> createState() =>
      _ExtraordinaryValuesPageState();
}

class _ExtraordinaryValuesPageState extends State<ExtraordinaryValuesPage> {
  late final BillingValueConfigFirestoreService _service =
      widget.service ?? BillingValueConfigFirestoreService();
  late final BillingPeriodFirestoreService _periodService =
      widget.periodService ?? BillingPeriodFirestoreService();
  late final UserFirestoreService _userService =
      widget.userService ?? UserFirestoreService();

  final TextEditingController _searchController = TextEditingController();
  late final Future<_ExtraordinaryReferences> _referencesFuture =
      _loadReferences();

  String _query = '';
  String _scopeFilter = 'massive';
  String? _periodFilter;
  bool _hasSearched = false;
  bool _saving = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<_ExtraordinaryReferences> _loadReferences() async {
    final results = await Future.wait([
      _periodService.fetchOperationalPeriods(),
      _userService.fetchActiveClients(limit: 5000),
    ]);
    final periods = results[0] as List<BillingPeriod>;
    if (mounted && _periodFilter == null && periods.isNotEmpty) {
      final selected = periods.firstWhere(
        (item) => item.vigente,
        orElse: () => periods.first,
      );
      setState(() => _periodFilter = selected.id);
    }
    return _ExtraordinaryReferences(
      periods: periods,
      clients: results[1] as List<AppUser>,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ExtraordinaryReferences>(
      future: _referencesFuture,
      builder: (context, referencesSnapshot) {
        if (referencesSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (referencesSnapshot.hasError) {
          return Center(
            child: Text(
              'No fue posible cargar referencias: ${referencesSnapshot.error}',
            ),
          );
        }
        final references = referencesSnapshot.data!;
        return StreamBuilder<BillingValueConfig?>(
          stream: _service.watchActiveItem(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Text('No fue posible cargar los extraordinarios.'),
              );
            }
            if (!snapshot.hasData) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
            }

            final activeItem = snapshot.data;
            final values = activeItem?.valoresAdicionales ?? const [];
            final rows = _buildRows(values, references.clients);
            final filteredRows = _hasSearched
                ? _filterRows(rows)
                : const <_ExtraordinaryRow>[];

            return Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Header(
                      enabled: activeItem != null,
                      totalCount: _hasSearched ? rows.length : 0,
                      filteredCount: filteredRows.length,
                      totalAmount: _hasSearched ? _sum(values) : 0,
                      filteredAmount: _sum(
                        filteredRows.map((item) => item.value),
                      ),
                      onAddMassive: activeItem == null
                          ? null
                          : () => _openForm(
                              activeItem: activeItem,
                              references: references,
                              initialMassive: true,
                            ),
                      onAddIndividual: activeItem == null
                          ? null
                          : () => _openForm(
                              activeItem: activeItem,
                              references: references,
                              initialMassive: false,
                            ),
                    ),
                    const SizedBox(height: 16),
                    _Filters(
                      searchController: _searchController,
                      query: _query,
                      scopeFilter: _scopeFilter,
                      periodFilter: _periodFilter,
                      periods: references.periods,
                      onSearchChanged: (value) =>
                          setState(() => _hasSearched = false),
                      onSearch: _search,
                      onScopeChanged: (value) => setState(() {
                        _scopeFilter = value;
                        _hasSearched = false;
                      }),
                      onPeriodChanged: (value) => setState(() {
                        _periodFilter = value;
                        _hasSearched = false;
                      }),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: activeItem == null
                          ? const Center(
                              child: Text(
                                'Primero crea una configuracion de valores activa.',
                              ),
                            )
                          : !_hasSearched
                          ? const Center(
                              child: Text(
                                'Selecciona los filtros y presiona Buscar.',
                              ),
                            )
                          : filteredRows.isEmpty
                          ? Center(
                              child: Text(
                                rows.isEmpty
                                    ? 'No hay extraordinarios configurados.'
                                    : 'No hay extraordinarios que coincidan con la busqueda.',
                              ),
                            )
                          : ListView.separated(
                              itemCount: filteredRows.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final row = filteredRows[index];
                                return _ExtraordinaryCard(
                                  row: row,
                                  onEdit: () => _openForm(
                                    activeItem: activeItem,
                                    references: references,
                                    editingIndex: row.originalIndex,
                                    existingValue: row.value,
                                  ),
                                  onDelete: () => _deleteValue(
                                    activeItem,
                                    row.originalIndex,
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
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
          },
        );
      },
    );
  }

  List<_ExtraordinaryRow> _buildRows(
    List<AdditionalBillingValue> values,
    List<AppUser> clients,
  ) {
    final clientsByCode = {
      for (final client in clients)
        for (final code in client.codigosUsuario)
          code.codigoUsuario.trim().toUpperCase(): _ClientCodeReference(
            client: client,
            code: code,
          ),
    };

    return List.generate(values.length, (index) {
      final value = values[index];
      final ref =
          clientsByCode[(value.codigoUsuario ?? '').trim().toUpperCase()];
      return _ExtraordinaryRow(
        originalIndex: index,
        value: value,
        clientReference: ref,
      );
    });
  }

  List<_ExtraordinaryRow> _filterRows(List<_ExtraordinaryRow> rows) {
    final query = _query.trim().toLowerCase();
    return rows.where((row) {
      if (_scopeFilter == 'massive' && !row.value.isMassive) {
        return false;
      }
      if (_scopeFilter == 'individual' && row.value.isMassive) {
        return false;
      }
      if (query.isEmpty &&
          (_periodFilter ?? '').isNotEmpty &&
          row.value.periodoId != _periodFilter) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      return row.searchText.contains(query);
    }).toList();
  }

  void _search() {
    setState(() {
      _query = _searchController.text.trim();
      _hasSearched = true;
    });
  }

  Future<void> _openForm({
    required BillingValueConfig activeItem,
    required _ExtraordinaryReferences references,
    bool initialMassive = true,
    int? editingIndex,
    AdditionalBillingValue? existingValue,
  }) async {
    final result = await showDialog<AdditionalBillingValue>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ExtraordinaryFormDialog(
        periods: references.periods,
        clients: references.clients,
        initialMassive: initialMassive,
        existingValue: existingValue,
      ),
    );
    if (result == null) {
      return;
    }

    final values = [...activeItem.valoresAdicionales];
    if (editingIndex == null) {
      values.add(result);
    } else {
      values[editingIndex] = result;
    }
    await _saveValues(activeItem, values);
  }

  Future<void> _deleteValue(BillingValueConfig activeItem, int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar extraordinario'),
        content: const Text(
          'Se quitara este cargo de la configuracion activa.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    final values = [...activeItem.valoresAdicionales]..removeAt(index);
    await _saveValues(activeItem, values);
  }

  Future<void> _saveValues(
    BillingValueConfig activeItem,
    List<AdditionalBillingValue> values,
  ) async {
    setState(() => _saving = true);
    final now = DateTime.now();
    final updated = BillingValueConfig(
      id: 'valor_facturacion_${now.microsecondsSinceEpoch}',
      estado: 'activo',
      version: activeItem.version + 1,
      periodoInicio: activeItem.periodoInicio,
      periodoInicioNombre: activeItem.periodoInicioNombre,
      cargoFijo: activeItem.cargoFijo,
      reconexion: activeItem.reconexion,
      rangos: activeItem.rangos,
      valoresAdicionales: values,
      actorUid: widget.currentUser.uid,
      actorNombre: widget.currentUser.nombre,
      fechaCreacion: now,
      fechaActualizacion: null,
    );

    try {
      await _service.saveNewVersion(item: updated, previousActive: activeItem);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Extraordinarios actualizados.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No fue posible guardar: $error')));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}
