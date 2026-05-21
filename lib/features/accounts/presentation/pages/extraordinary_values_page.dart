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
                      onScopeChanged: (value) =>
                          setState(() {
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
      final ref = clientsByCode[(value.codigoUsuario ?? '').trim().toUpperCase()];
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
        content: const Text('Se quitara este cargo de la configuracion activa.'),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No fue posible guardar: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.enabled,
    required this.totalCount,
    required this.filteredCount,
    required this.totalAmount,
    required this.filteredAmount,
    required this.onAddMassive,
    required this.onAddIndividual,
  });

  final bool enabled;
  final int totalCount;
  final int filteredCount;
  final int totalAmount;
  final int filteredAmount;
  final VoidCallback? onAddMassive;
  final VoidCallback? onAddIndividual;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final title = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Extraordinarios',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _SummaryChip(label: 'Registros', value: '$filteredCount/$totalCount'),
                _SummaryChip(
                  label: 'Valor filtrado',
                  value: _formatCurrency(filteredAmount),
                ),
                _SummaryChip(
                  label: 'Valor total',
                  value: _formatCurrency(totalAmount),
                ),
              ],
            ),
          ],
        );
        final actions = Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          children: [
            OutlinedButton.icon(
              onPressed: enabled ? onAddIndividual : null,
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Cargo individual'),
            ),
            FilledButton.icon(
              onPressed: enabled ? onAddMassive : null,
              style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
              icon: const Icon(Icons.groups_rounded),
              label: const Text('Cargo masivo'),
            ),
          ],
        );
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [title, const SizedBox(height: 12), actions],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: title),
            const SizedBox(width: 16),
            actions,
          ],
        );
      },
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.searchController,
    required this.query,
    required this.scopeFilter,
    required this.periodFilter,
    required this.periods,
    required this.onSearchChanged,
    required this.onSearch,
    required this.onScopeChanged,
    required this.onPeriodChanged,
  });

  final TextEditingController searchController;
  final String query;
  final String scopeFilter;
  final String? periodFilter;
  final List<BillingPeriod> periods;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearch;
  final ValueChanged<String> onScopeChanged;
  final ValueChanged<String?> onPeriodChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: searchController,
                  onChanged: onSearchChanged,
                  onSubmitted: (_) => onSearch(),
                  decoration: const InputDecoration(
                    labelText: 'Buscar por codigo, sector, nombre o concepto',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: onSearch,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 56),
                ),
                icon: const Icon(Icons.search_rounded),
                label: const Text('Buscar'),
              ),
            ],
          ),
          if (query.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'La busqueda se realiza en todos los periodos.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ChoiceChip(
                label: const Text('Masivos'),
                selected: scopeFilter == 'massive',
                onSelected: (_) => onScopeChanged('massive'),
              ),
              ChoiceChip(
                label: const Text('Individuales'),
                selected: scopeFilter == 'individual',
                onSelected: (_) => onScopeChanged('individual'),
              ),
              SizedBox(
                width: 260,
                child: DropdownButtonFormField<String?>(
                  isExpanded: true,
                  initialValue: periodFilter,
                  decoration: const InputDecoration(labelText: 'Periodo'),
                  items: periods
                      .map(
                      (period) => DropdownMenuItem<String?>(
                        value: period.id,
                        child: Text(
                          _displayPeriod(period),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                      .toList(),
                  onChanged: onPeriodChanged,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExtraordinaryCard extends StatelessWidget {
  const _ExtraordinaryCard({
    required this.row,
    required this.onEdit,
    required this.onDelete,
  });

  final _ExtraordinaryRow row;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final item = row.value;
    final ref = row.clientReference;
    final scopeLabel = item.isMassive ? 'Masivo' : 'Individual';
    final title = item.concepto.trim().isEmpty ? 'Extraordinario' : item.concepto;
    final target = item.isMassive
        ? 'Todos los usuarios'
        : ref == null
        ? 'Codigo ${item.codigoUsuario}'
        : '${toDisplayUserName(ref.client.nombre)} - ${ref.code.codigoUsuario}';
    final detail = item.isMassive
        ? 'Aplica a todos los recibos del periodo'
        : 'Sector: ${_displaySector(ref?.code.sector ?? '')} - Contador: ${ref?.code.numeroContador ?? 'NA'}';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          final info = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  Chip(label: Text(scopeLabel)),
                  Chip(label: Text(item.periodoNombre.isEmpty ? item.periodoId : item.periodoNombre)),
                ],
              ),
              const SizedBox(height: 8),
              Text(target),
              const SizedBox(height: 4),
              Text(detail, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 8),
              Text(
                _formatCurrency(item.valor),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          );
          final actions = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onEdit,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                ),
                icon: const Icon(Icons.edit_rounded),
                label: const Text('Editar'),
              ),
              OutlinedButton.icon(
                onPressed: onDelete,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                ),
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Eliminar'),
              ),
            ],
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [info, const SizedBox(height: 14), actions],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: info),
              const SizedBox(width: 12),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _ExtraordinaryFormDialog extends StatefulWidget {
  const _ExtraordinaryFormDialog({
    required this.periods,
    required this.clients,
    required this.initialMassive,
    this.existingValue,
  });

  final List<BillingPeriod> periods;
  final List<AppUser> clients;
  final bool initialMassive;
  final AdditionalBillingValue? existingValue;

  @override
  State<_ExtraordinaryFormDialog> createState() =>
      _ExtraordinaryFormDialogState();
}

class _ExtraordinaryFormDialogState extends State<_ExtraordinaryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final bool _isMassive =
      widget.existingValue?.isMassive ?? widget.initialMassive;
  late String? _periodId = widget.existingValue?.periodoId.isEmpty == true
      ? null
      : widget.existingValue?.periodoId;
  late _ClientCodeReference? _selectedClient = _initialClient();
  final TextEditingController _clientNameSearchController =
      TextEditingController();
  final TextEditingController _clientCodeSearchController =
      TextEditingController();
  final TextEditingController _clientSectorSearchController =
      TextEditingController();
  late final TextEditingController _conceptController = TextEditingController(
    text: widget.existingValue?.concepto ?? '',
  );
  late final TextEditingController _amountController = TextEditingController(
    text: widget.existingValue == null ? '' : '${widget.existingValue!.valor}',
  );

  @override
  void dispose() {
    _clientNameSearchController.dispose();
    _clientCodeSearchController.dispose();
    _clientSectorSearchController.dispose();
    _conceptController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clientChoices = _filteredClientChoices;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.existingValue == null
                        ? 'Nuevo extraordinario'
                        : 'Editar extraordinario',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: 260,
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: _periodId,
                          decoration: const InputDecoration(labelText: 'Periodo'),
                          items: widget.periods
                              .map(
                                (period) => DropdownMenuItem<String>(
                                  value: period.id,
                                  child: Text(
                                    _displayPeriod(period),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) => setState(() => _periodId = value),
                          validator: (value) =>
                              (value ?? '').trim().isEmpty
                              ? 'Selecciona un periodo.'
                              : null,
                        ),
                      ),
                      InputChip(
                        avatar: Icon(
                          _isMassive
                              ? Icons.groups_rounded
                              : Icons.person_rounded,
                        ),
                        label: Text(_isMassive ? 'Masivo' : 'Individual'),
                      ),
                    ],
                  ),
                  if (!_isMassive) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Seleccionar usuario',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              SizedBox(
                                width: 220,
                                child: TextField(
                                  controller: _clientNameSearchController,
                                  decoration: const InputDecoration(
                                    labelText: 'Buscar por nombre',
                                    prefixIcon: Icon(Icons.person_search_rounded),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                              SizedBox(
                                width: 200,
                                child: TextField(
                                  controller: _clientCodeSearchController,
                                  decoration: const InputDecoration(
                                    labelText: 'Buscar por codigo',
                                    prefixIcon: Icon(Icons.tag_rounded),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                              SizedBox(
                                width: 200,
                                child: TextField(
                                  controller: _clientSectorSearchController,
                                  decoration: const InputDecoration(
                                    labelText: 'Buscar por sector',
                                    prefixIcon: Icon(Icons.map_rounded),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_selectedClient != null) ...[
                            _SelectedClientPreview(item: _selectedClient!),
                            const SizedBox(height: 12),
                          ],
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 260),
                            child: clientChoices.isEmpty
                                ? const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Text(
                                        'No hay usuarios que coincidan con la busqueda.',
                                      ),
                                    ),
                                  )
                                : ListView.separated(
                                    shrinkWrap: true,
                                    itemCount: clientChoices.length,
                                    separatorBuilder: (_, _) =>
                                        const SizedBox(height: 8),
                                    itemBuilder: (context, index) {
                                      final item = clientChoices[index];
                                      final selected = item == _selectedClient;
                                      return _ClientChoiceTile(
                                        item: item,
                                        selected: selected,
                                        onTap: () => setState(
                                          () => _selectedClient = item,
                                        ),
                                      );
                                    },
                                  ),
                          ),
                          FormField<_ClientCodeReference>(
                            initialValue: _selectedClient,
                            validator: (_) => _selectedClient == null
                                ? 'Selecciona un usuario.'
                                : null,
                            builder: (field) => field.hasError
                                ? Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      field.errorText!,
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error,
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _conceptController,
                    decoration: const InputDecoration(
                      labelText: 'Concepto',
                      hintText: 'Saldo anterior, cuota extraordinaria, multa...',
                    ),
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? 'Campo obligatorio.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Valor'),
                    validator: (value) {
                      final amount = int.tryParse(value?.trim() ?? '');
                      if (amount == null || amount <= 0) {
                        return 'Ingresa un valor mayor a 0.';
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
                        child: const Text('Guardar'),
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

  List<_ClientCodeReference> get _clientChoices {
    return [
      for (final client in widget.clients)
        for (final code in client.codigosUsuario)
          if (code.codigoUsuario.trim().isNotEmpty)
            _ClientCodeReference(client: client, code: code),
    ];
  }

  List<_ClientCodeReference> get _filteredClientChoices {
    final nameQuery = _clientNameSearchController.text.trim().toLowerCase();
    final codeQuery = _clientCodeSearchController.text.trim().toLowerCase();
    final sectorQuery = _clientSectorSearchController.text.trim().toLowerCase();
    return _clientChoices.where((item) {
      if (nameQuery.isNotEmpty &&
          !item.client.nombre.toLowerCase().contains(nameQuery)) {
        return false;
      }
      if (codeQuery.isNotEmpty &&
          !item.code.codigoUsuario.toLowerCase().contains(codeQuery)) {
        return false;
      }
      if (sectorQuery.isNotEmpty &&
          !item.code.sector.toLowerCase().contains(sectorQuery) &&
          !_displaySector(item.code.sector).toLowerCase().contains(sectorQuery)) {
        return false;
      }
      return true;
    }).toList();
  }

  _ClientCodeReference? _initialClient() {
    final code = widget.existingValue?.codigoUsuario?.trim().toUpperCase();
    if (code == null || code.isEmpty) {
      return null;
    }
    for (final item in _clientChoices) {
      if (item.code.codigoUsuario.trim().toUpperCase() == code) {
        return item;
      }
    }
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final period = widget.periods.firstWhere((item) => item.id == _periodId);
    Navigator.of(context).pop(
      AdditionalBillingValue(
        periodoId: period.id,
        periodoNombre: period.nombre,
        concepto: _conceptController.text.trim(),
        valor: int.parse(_amountController.text.trim()),
        codigoUsuario: _isMassive ? null : _selectedClient?.code.codigoUsuario,
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text('$label: $value'));
  }
}

class _SelectedClientPreview extends StatelessWidget {
  const _SelectedClientPreview({required this.item});

  final _ClientCodeReference item;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.primary),
      ),
      child: Text(
        'Seleccionado: ${toDisplayUserName(item.client.nombre)} - ${item.code.codigoUsuario} - ${_displaySector(item.code.sector)}',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ClientChoiceTile extends StatelessWidget {
  const _ClientChoiceTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _ClientCodeReference item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? colorScheme.primary.withValues(alpha: 0.10)
          : AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? colorScheme.primary : AppColors.textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      toDisplayUserName(item.client.nombre),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Codigo: ${item.code.codigoUsuario} - Sector: ${_displaySector(item.code.sector)} - Contador: ${item.code.numeroContador}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExtraordinaryReferences {
  const _ExtraordinaryReferences({
    required this.periods,
    required this.clients,
  });

  final List<BillingPeriod> periods;
  final List<AppUser> clients;
}

class _ExtraordinaryRow {
  const _ExtraordinaryRow({
    required this.originalIndex,
    required this.value,
    required this.clientReference,
  });

  final int originalIndex;
  final AdditionalBillingValue value;
  final _ClientCodeReference? clientReference;

  String get searchText {
    final ref = clientReference;
    return [
      value.periodoId,
      value.periodoNombre,
      value.concepto,
      value.codigoUsuario ?? '',
      ref?.client.nombre ?? '',
      ref?.client.numeroDocumento ?? '',
      ref?.client.numeroContacto ?? '',
      ref?.code.codigoUsuario ?? '',
      ref?.code.numeroContador ?? '',
      ref?.code.sector ?? '',
    ].join(' ').toLowerCase();
  }
}

class _ClientCodeReference {
  const _ClientCodeReference({required this.client, required this.code});

  final AppUser client;
  final ClientUserCode code;

  @override
  bool operator ==(Object other) {
    return other is _ClientCodeReference &&
        other.client.uid == client.uid &&
        other.code.codigoUsuario == code.codigoUsuario;
  }

  @override
  int get hashCode => Object.hash(client.uid, code.codigoUsuario);
}

int _sum(Iterable<AdditionalBillingValue> values) {
  return values.fold(0, (previous, item) => previous + item.valor);
}

String _displayPeriod(BillingPeriod period) {
  final name = period.nombre.trim();
  if (name.isEmpty) {
    return period.id;
  }
  return '$name (${period.id})';
}

String _displaySector(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty || normalized.toLowerCase() == 'na') {
    return 'Sin sector';
  }
  return toDisplayText(normalized);
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
