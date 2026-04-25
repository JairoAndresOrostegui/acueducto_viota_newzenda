import 'package:flutter/material.dart';

import '../../../../../theme/app_colors.dart';
import '../../../periods/data/billing_period_firestore_service.dart';
import '../../../periods/domain/billing_period.dart';
import '../../../../users/data/user_firestore_service.dart';
import '../../../../users/domain/app_user.dart';
import '../../data/billing_observation_firestore_service.dart';
import '../../domain/billing_observation.dart';

class BillingObservationsAdminPage extends StatefulWidget {
  const BillingObservationsAdminPage({
    super.key,
    this.service,
    this.periodService,
    this.userService,
  });

  final BillingObservationFirestoreService? service;
  final BillingPeriodFirestoreService? periodService;
  final UserFirestoreService? userService;

  @override
  State<BillingObservationsAdminPage> createState() =>
      _BillingObservationsAdminPageState();
}

class _BillingObservationsAdminPageState
    extends State<BillingObservationsAdminPage> {
  final TextEditingController _searchController = TextEditingController();
  late final BillingObservationFirestoreService _service =
      widget.service ?? BillingObservationFirestoreService();
  late final BillingPeriodFirestoreService _periodService =
      widget.periodService ?? BillingPeriodFirestoreService();
  late final UserFirestoreService _userService =
      widget.userService ?? UserFirestoreService();

  bool _loadingReferences = true;
  String _search = '';
  List<BillingPeriod> _periods = const [];
  List<AppUser> _clients = const [];

  @override
  void initState() {
    super.initState();
    _loadReferences();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadReferences() async {
    setState(() => _loadingReferences = true);
    try {
      final results = await Future.wait([
        _periodService.fetchPeriods(),
        _userService.fetchActiveClients(),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _periods = results[0] as List<BillingPeriod>;
        _clients = results[1] as List<AppUser>;
      });
    } finally {
      if (mounted) {
        setState(() => _loadingReferences = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingReferences) {
      return const Center(child: CircularProgressIndicator());
    }

    return StreamBuilder<List<BillingObservation>>(
      stream: _service.watchItems(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text('No fue posible cargar las observaciones.'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = snapshot.data!;
        final query = _search.trim().toLowerCase();
        final filtered = items.where((item) {
          if (query.isEmpty) {
            return true;
          }
          return item.descripcion.toLowerCase().contains(query) ||
              (item.nombreUsuario ?? '').toLowerCase().contains(query) ||
              (item.codigoUsuario ?? '').toLowerCase().contains(query) ||
              (item.periodo ?? '').toLowerCase().contains(query) ||
              item.tipo.toLowerCase().contains(query);
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              totalLabel: '${filtered.length}/${items.length}',
              onCreate: () => _openForm(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _search = value),
              decoration: const InputDecoration(
                labelText: 'Buscar observaciones',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Text('No hay observaciones para mostrar.'),
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        return _ObservationCard(
                          item: item,
                          onEdit: () => _openForm(item: item),
                          onDelete: () => _delete(item),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openForm({BillingObservation? item}) async {
    final result = await showDialog<BillingObservation>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ObservationDialog(
        item: item,
        periods: _periods,
        clients: _clients,
      ),
    );

    if (result == null) {
      return;
    }

    try {
      await _service.saveItem(result);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Observación guardada correctamente.'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No fue posible guardar: $error')),
      );
    }
  }

  Future<void> _delete(BillingObservation item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar observación'),
        content: const Text('Se eliminará esta observación de facturación.'),
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

    try {
      await _service.deleteItem(item.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Observación eliminada correctamente.'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No fue posible eliminar: $error')),
      );
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.totalLabel,
    required this.onCreate,
  });

  final String totalLabel;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Observaciones', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          'Define observaciones masivas o individuales para que queden guardadas dentro del recibo al momento de facturarlo.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 8),
        Text('Registros cargados: $totalLabel'),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: ElevatedButton.icon(
            onPressed: onCreate,
            style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Nueva'),
          ),
        ),
      ],
    );
  }
}

class _ObservationDialog extends StatefulWidget {
  const _ObservationDialog({
    required this.periods,
    required this.clients,
    this.item,
  });

  final BillingObservation? item;
  final List<BillingPeriod> periods;
  final List<AppUser> clients;

  @override
  State<_ObservationDialog> createState() => _ObservationDialogState();
}

class _ObservationDialogState extends State<_ObservationDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _descriptionController =
      TextEditingController(text: widget.item?.descripcion ?? '');

  late String _type = widget.item?.tipo ?? 'masiva';
  late bool _always = widget.item?.siempre ?? false;
  BillingPeriod? _selectedPeriod;
  AppUser? _selectedClient;

  bool get _isEditing => widget.item != null;
  bool get _isMassive => _type == 'masiva';

  @override
  void initState() {
    super.initState();
    _selectedPeriod = widget.periods.cast<BillingPeriod?>().firstWhere(
          (item) => item?.id == widget.item?.periodo,
          orElse: () => null,
        );
    _selectedClient = widget.clients.cast<AppUser?>().firstWhere(
          (item) => item?.codigoUsuario == widget.item?.codigoUsuario,
          orElse: () => null,
        );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                    _isEditing
                        ? 'Editar observación'
                        : 'Nueva observación',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Las observaciones se copian dentro del recibo generado para conservar trazabilidad.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    initialValue: _type,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de observación',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'masiva',
                        child: Text('Masiva'),
                      ),
                      DropdownMenuItem(
                        value: 'individual',
                        child: Text('Individual'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        _type = value;
                        if (_isMassive) {
                          _selectedClient = null;
                        } else {
                          _always = false;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  if (_isMassive)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Aplicar siempre'),
                      subtitle: const Text(
                        'Si se activa, la observación aparecerá en todos los períodos futuros.',
                      ),
                      value: _always,
                      onChanged: (value) => setState(() => _always = value),
                    ),
                  if (!_isMassive) ...[
                    DropdownButtonFormField<AppUser>(
                      isExpanded: true,
                      initialValue: _selectedClient,
                      decoration: const InputDecoration(
                        labelText: 'Usuario',
                      ),
                      items: widget.clients
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(
                                '${item.nombre} · ${item.codigoUsuario}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _selectedClient = value),
                      validator: (value) {
                        if (!_isMassive && value == null) {
                          return 'Selecciona un usuario.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (!_always)
                    DropdownButtonFormField<BillingPeriod>(
                      isExpanded: true,
                      initialValue: _selectedPeriod,
                      decoration: const InputDecoration(
                        labelText: 'Período',
                      ),
                      items: widget.periods
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(item.nombre),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _selectedPeriod = value),
                      validator: (value) {
                        if (!_always && value == null) {
                          return 'Selecciona un período.';
                        }
                        return null;
                      },
                    ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 5,
                    minLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Observación',
                      alignLabelWithHint: true,
                    ),
                    validator: _required,
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

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Campo obligatorio.';
    }
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final now = DateTime.now();
    final item = BillingObservation(
      id: widget.item?.id ?? 'obs_fact_${now.microsecondsSinceEpoch}',
      descripcion: _descriptionController.text.trim(),
      tipo: _type,
      siempre: _isMassive ? _always : false,
      fechaCreacion: widget.item?.fechaCreacion ?? now,
      fechaActualizacion: _isEditing ? now : null,
      periodo: _isMassive && _always ? null : _selectedPeriod?.id,
      codigoUsuario: _isMassive ? null : _selectedClient?.codigoUsuario,
      nombreUsuario: _isMassive ? null : _selectedClient?.nombre,
    );

    Navigator.of(context).pop(item);
  }
}

class _ObservationCard extends StatelessWidget {
  const _ObservationCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  final BillingObservation item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scopeLabel = item.siempre
        ? 'Siempre'
        : (item.periodo == null || item.periodo!.isEmpty)
            ? 'Sin período'
            : item.periodo!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
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
                children: [
                  Chip(label: Text(item.isMassive ? 'Masiva' : 'Individual')),
                  Chip(label: Text(scopeLabel)),
                  if (!item.isMassive && (item.nombreUsuario ?? '').isNotEmpty)
                    Chip(label: Text(item.nombreUsuario!)),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                item.descripcion,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              if ((item.codigoUsuario ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Código usuario: ${item.codigoUsuario}'),
              ],
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
              children: [
                info,
                const SizedBox(height: 16),
                actions,
              ],
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
