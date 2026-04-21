import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/presentation/text_formatters.dart';
import '../../../../theme/app_colors.dart';
import '../../data/consumption_conflict_firestore_service.dart';
import '../../data/consumption_firestore_service.dart';
import '../../domain/consumption_conflict.dart';
import '../../domain/consumption_reading.dart';
import '../../../users/domain/app_user.dart';

class ConsumptionConflictsAdminPage extends StatefulWidget {
  const ConsumptionConflictsAdminPage({
    super.key,
    required this.currentUser,
    this.conflictService,
    this.firestoreService,
  });

  final AppUser currentUser;
  final ConsumptionConflictFirestoreService? conflictService;
  final ConsumptionFirestoreService? firestoreService;

  @override
  State<ConsumptionConflictsAdminPage> createState() =>
      _ConsumptionConflictsAdminPageState();
}

class _ConsumptionConflictsAdminPageState
    extends State<ConsumptionConflictsAdminPage> {
  late final ConsumptionConflictFirestoreService _conflictService =
      widget.conflictService ?? ConsumptionConflictFirestoreService();
  late final ConsumptionFirestoreService _firestoreService =
      widget.firestoreService ?? ConsumptionFirestoreService();

  bool _isBusy = false;
  List<ConsumptionConflict> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AbsorbPointer(
          absorbing: _isBusy,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ConflictsHeader(
                pendingCount: _items.length,
                onRefresh: _load,
              ),
              const SizedBox(height: 20),
              Expanded(
                child: _items.isEmpty
                    ? const Center(
                        child: Text(
                          'No hay conflictos pendientes en consumos.',
                        ),
                      )
                    : ListView.separated(
                        itemCount: _items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return _ConflictCard(
                            item: item,
                            onResolve: () => _resolve(item),
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

  Future<void> _load() async {
    setState(() => _isBusy = true);
    try {
      final items = await _conflictService.fetchPendingConflicts();
      if (!mounted) {
        return;
      }
      setState(() => _items = items);
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _resolve(ConsumptionConflict conflict) async {
    final result = await showDialog<_ConflictResolutionResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ResolveConflictDialog(conflict: conflict),
    );
    if (result == null) {
      return;
    }

    setState(() => _isBusy = true);
    try {
      await _firestoreService.saveReading(result.finalReading);
      await _conflictService.resolveConflict(
        conflict: conflict,
        finalReading: result.finalReading,
        adminUid: widget.currentUser.uid,
        adminName: widget.currentUser.nombre,
      );
      if (!mounted) {
        return;
      }
      await _load();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Conflicto resuelto correctamente.'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('No fue posible resolver el conflicto'),
          content: Text('$error'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }
}

class _ConflictsHeader extends StatelessWidget {
  const _ConflictsHeader({
    required this.pendingCount,
    required this.onRefresh,
  });

  final int pendingCount;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final info = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Conflictos de consumos',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Aqui el administrador decide cual lectura queda oficial cuando hay doble captura o una lectura menor a la anterior.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Text('Pendientes: $pendingCount'),
          ],
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              info,
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onRefresh,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                ),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Actualizar'),
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: info),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              onPressed: onRefresh,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 48),
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Actualizar'),
            ),
          ],
        );
      },
    );
  }
}

class _ConflictCard extends StatelessWidget {
  const _ConflictCard({
    required this.item,
    required this.onResolve,
  });

  final ConsumptionConflict item;
  final VoidCallback onResolve;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final info = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                toDisplayUserName(item.lecturaPropuesta.nombreUsuario),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                'Codigo usuario: ${item.lecturaPropuesta.codigoUsuario} - Contador: ${item.lecturaPropuesta.codigoContador}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'Periodo: ${item.lecturaPropuesta.periodoActual} - Motivo: ${_motivoLabel(item.motivo)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'Propuesta: ${item.lecturaPropuesta.lecturaActual} - Operario: ${toDisplayUserName(item.lecturaPropuesta.nombreOperario)}',
              ),
              if (item.lecturaExistente != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Actual en sistema: ${item.lecturaExistente!.lecturaActual} - Operario: ${toDisplayUserName(item.lecturaExistente!.nombreOperario)}',
                ),
              ],
              if (item.lecturaAnterior != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Ultima lectura anterior: ${item.lecturaAnterior!.lecturaActual} (${item.lecturaAnterior!.periodoActual})',
                ),
              ],
              const SizedBox(height: 8),
              Text(
                item.mensaje,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.orange.shade900,
                ),
              ),
            ],
          );

          final action = ElevatedButton.icon(
            onPressed: onResolve,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, 44),
            ),
            icon: const Icon(Icons.rule_folder_rounded),
            label: const Text('Resolver'),
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

  String _motivoLabel(String value) {
    switch (value) {
      case 'lectura_existente':
        return 'Lectura duplicada';
      case 'lectura_menor':
        return 'Lectura menor que la anterior';
      default:
        return value;
    }
  }
}

class _ResolveConflictDialog extends StatefulWidget {
  const _ResolveConflictDialog({
    required this.conflict,
  });

  final ConsumptionConflict conflict;

  @override
  State<_ResolveConflictDialog> createState() => _ResolveConflictDialogState();
}

class _ResolveConflictDialogState extends State<_ResolveConflictDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _manualValueController = TextEditingController();
  String _selection = 'propuesta';

  @override
  void initState() {
    super.initState();
    if (widget.conflict.lecturaExistente != null) {
      _selection = 'existente';
    }
  }

  @override
  void dispose() {
    _manualValueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Resolver conflicto',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 20),
                  _ResolutionOptionTile(
                    enabled: widget.conflict.lecturaExistente != null,
                    value: 'existente',
                    groupValue: _selection,
                    title:
                        'Mantener lectura actual del sistema (${widget.conflict.lecturaExistente?.lecturaActual ?? '-'})',
                    onChanged: _updateSelection,
                  ),
                  const SizedBox(height: 8),
                  _ResolutionOptionTile(
                    enabled: true,
                    value: 'propuesta',
                    groupValue: _selection,
                    title:
                        'Usar lectura propuesta (${widget.conflict.lecturaPropuesta.lecturaActual})',
                    onChanged: _updateSelection,
                  ),
                  const SizedBox(height: 8),
                  _ResolutionOptionTile(
                    enabled: true,
                    value: 'manual',
                    groupValue: _selection,
                    title: 'Ingresar valor manual',
                    onChanged: _updateSelection,
                  ),
                  if (_selection == 'manual') ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _manualValueController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Valor final',
                      ),
                      validator: (value) {
                        if (_selection != 'manual') {
                          return null;
                        }
                        final parsed = int.tryParse(value?.trim() ?? '');
                        if (parsed == null) {
                          return 'Ingresa un valor valido.';
                        }
                        final previous = widget.conflict.lecturaAnterior;
                        if (previous != null &&
                            parsed < previous.lecturaActual) {
                          return 'No puede ser menor que ${previous.lecturaActual}.';
                        }
                        return null;
                      },
                    ),
                  ],
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
                        child: const Text('Guardar decision'),
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

  void _updateSelection(String? value) {
    if (value == null) {
      return;
    }
    setState(() => _selection = value);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final finalReading = _buildFinalReading();
    if (finalReading == null) {
      return;
    }
    final previous = widget.conflict.lecturaAnterior;
    if (previous != null && finalReading.lecturaActual < previous.lecturaActual) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'El valor final no puede ser menor que ${previous.lecturaActual}.',
          ),
        ),
      );
      return;
    }

    Navigator.of(context).pop(_ConflictResolutionResult(finalReading));
  }

  ConsumptionReading? _buildFinalReading() {
    switch (_selection) {
      case 'existente':
        final existing = widget.conflict.lecturaExistente;
        if (existing == null) {
          return null;
        }
        return existing.copyWith(
          estado: 'sincronizado',
          conflictoId: null,
          detalleEstado: null,
        );
      case 'manual':
        final value = int.parse(_manualValueController.text.trim());
        return widget.conflict.lecturaPropuesta.copyWith(
          lecturaActual: value,
          fecha: DateTime.now(),
          nombreOperario: widget.conflict.lecturaPropuesta.nombreOperario,
          actorUid: widget.conflict.lecturaPropuesta.actorUid,
          estado: 'sincronizado',
          conflictoId: null,
          detalleEstado: null,
        );
      case 'propuesta':
      default:
        return widget.conflict.lecturaPropuesta.copyWith(
          estado: 'sincronizado',
          conflictoId: null,
          detalleEstado: null,
        );
    }
  }
}

class _ResolutionOptionTile extends StatelessWidget {
  const _ResolutionOptionTile({
    required this.enabled,
    required this.value,
    required this.groupValue,
    required this.title,
    required this.onChanged,
  });

  final bool enabled;
  final String value;
  final String groupValue;
  final String title;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: RadioListTile<String>(
        value: value,
        groupValue: groupValue,
        onChanged: enabled ? onChanged : null,
        title: Text(title),
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
}

class _ConflictResolutionResult {
  const _ConflictResolutionResult(this.finalReading);

  final ConsumptionReading finalReading;
}
