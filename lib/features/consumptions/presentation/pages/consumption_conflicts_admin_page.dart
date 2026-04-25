// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/presentation/text_formatters.dart';
import '../../../../theme/app_colors.dart';
import '../../data/consumption_conflict_firestore_service.dart';
import '../../data/consumption_firestore_service.dart';
import '../../domain/consumption_conflict.dart';
import '../../domain/consumption_history_entry.dart';
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
              _ConflictsHeader(pendingCount: _items.length, onRefresh: _load),
              const SizedBox(height: 20),
              Expanded(
                child: _items.isEmpty
                    ? const Center(
                        child: Text('No hay conflictos pendientes en consumos.'),
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
    final lockedReading = conflict.lecturaExistente ?? conflict.lecturaFinal;
    if (lockedReading?.pagado == true || lockedReading?.facturado == true) {
      await _showError(
        'Este consumo ya está facturado o pagado y no puede modificarse.',
      );
      return;
    }

    final result = await showDialog<_ConflictResolutionResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ResolveConflictDialog(
        conflict: conflict,
        currentUser: widget.currentUser,
      ),
    );
    if (result == null) {
      return;
    }

    setState(() => _isBusy = true);
    try {
      await _firestoreService.updateReadingWithCascade(
        updatedReading: result.finalReading,
        updateEntry: ConsumptionHistoryEntry(
          id: '${DateTime.now().microsecondsSinceEpoch}',
          tipoEvento: 'conflicto_resuelto',
          actorUid: widget.currentUser.uid,
          actorNombre: widget.currentUser.nombre,
          actorRol: widget.currentUser.rol,
          fecha: DateTime.now(),
          estadoAnterior:
              conflict.lecturaExistente?.estado ?? conflict.lecturaPropuesta.estado,
          estadoNuevo: result.finalReading.estado,
          valorAnterior: conflict.lecturaExistente?.lecturaActual,
          valorNuevo: result.finalReading.lecturaActual,
          motivo: result.warningMessage,
          observaciones: result.adminObservation,
        ),
        actorUid: widget.currentUser.uid,
        actorName: widget.currentUser.nombre,
        actorRole: widget.currentUser.rol,
      );
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
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conflicto resuelto correctamente.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      await _showError('$error');
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _showError(String message) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('No fue posible resolver el conflicto'),
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

class _ConflictsHeader extends StatelessWidget {
  const _ConflictsHeader({
    required this.pendingCount,
    required this.onRefresh,
  });

  final int pendingCount;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Conflictos de consumos',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'El administrador define la lectura oficial. Si el consumo ya fue facturado o pagado no se permite modificar.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 8),
              Text('Pendientes: $pendingCount'),
            ],
          ),
        ),
        const SizedBox(width: 16),
        ElevatedButton.icon(
          onPressed: onRefresh,
          style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Actualizar'),
        ),
      ],
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
    final existing = item.lecturaExistente;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            toDisplayUserName(item.lecturaPropuesta.nombreUsuario),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            'Código usuario: ${item.lecturaPropuesta.codigoUsuario} - Contador: ${item.lecturaPropuesta.codigoContador}',
          ),
          const SizedBox(height: 6),
          Text(
            'Período: ${item.lecturaPropuesta.periodoActual} - Motivo: ${_motivoLabel(item.motivo)}',
          ),
          const SizedBox(height: 12),
          Text(
            'Propuesta: ${item.lecturaPropuesta.lecturaActual} - Operario: ${toDisplayUserName(item.lecturaPropuesta.nombreOperario)}',
          ),
          if (existing != null) ...[
            const SizedBox(height: 6),
            Text(
              'Actual en sistema: ${existing.lecturaActual} - Facturado: ${existing.facturado ? 'sí' : 'no'} - Pagado: ${existing.pagado ? 'sí' : 'no'}',
            ),
          ],
          if (item.lecturaAnterior != null) ...[
            const SizedBox(height: 6),
            Text(
              'Última lectura anterior: ${item.lecturaAnterior!.lecturaActual} (${item.lecturaAnterior!.periodoActual})',
            ),
          ],
          const SizedBox(height: 8),
          Text(
            item.mensaje,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.orange.shade900,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: onResolve,
              style: ElevatedButton.styleFrom(minimumSize: const Size(0, 44)),
              icon: const Icon(Icons.rule_folder_rounded),
              label: const Text('Resolver'),
            ),
          ),
        ],
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
    required this.currentUser,
  });

  final ConsumptionConflict conflict;
  final AppUser currentUser;

  @override
  State<_ResolveConflictDialog> createState() => _ResolveConflictDialogState();
}

class _ResolveConflictDialogState extends State<_ResolveConflictDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _manualValueController = TextEditingController();
  final TextEditingController _observationController = TextEditingController();

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
    _observationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isFacturado = widget.conflict.lecturaExistente?.facturado ?? false;
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
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(labelText: 'Valor final'),
                      validator: (value) {
                        if (_selection != 'manual') {
                          return null;
                        }
                        final parsed = int.tryParse(value?.trim() ?? '');
                        if (parsed == null) {
                          return 'Ingresa un valor válido.';
                        }
                        final previous = widget.conflict.lecturaAnterior;
                        if (previous != null && parsed < previous.lecturaActual) {
                          return 'No puede ser menor que ${previous.lecturaActual}.';
                        }
                        return null;
                      },
                    ),
                  ],
                  if (isFacturado) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDF1DA),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        'Advertencia: este consumo ya fue facturado. Si cambias el valor, deberías comunicarte con la persona porque el sistema registrará la novedad.',
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _observationController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Observación administrativa',
                    ),
                    validator: (value) {
                      if (isFacturado && (value?.trim().isEmpty ?? true)) {
                        return 'Agrega una observación administrativa.';
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
                        child: const Text('Guardar decisión'),
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
    if (value != null) {
      setState(() => _selection = value);
    }
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
    Navigator.of(context).pop(
      _ConflictResolutionResult(
        finalReading,
        _observationController.text.trim(),
        (widget.conflict.lecturaExistente?.facturado ?? false)
            ? 'Consumo facturado: requiere comunicacion con el usuario.'
            : 'Conflicto resuelto por administrador.',
      ),
    );
  }

  ConsumptionReading? _buildFinalReading() {
    final previousValue = widget.conflict.lecturaAnterior?.lecturaActual;
    switch (_selection) {
      case 'existente':
        final existing = widget.conflict.lecturaExistente;
        if (existing == null) {
          return null;
        }
        return existing.copyWith(
          lecturaAnterior: previousValue,
          consumoCalculado:
              previousValue == null ? null : existing.lecturaActual - previousValue,
          estado: 'editado_admin',
          conflictoId: null,
          detalleEstado: null,
          observacionesAdmin: _observationController.text.trim().isEmpty
              ? null
              : _observationController.text.trim(),
          nombreOperario: widget.currentUser.nombre,
          actorUid: widget.currentUser.uid,
        );
      case 'manual':
        final value = int.parse(_manualValueController.text.trim());
        return widget.conflict.lecturaPropuesta.copyWith(
          lecturaActual: value,
          lecturaAnterior: previousValue,
          consumoCalculado: previousValue == null ? null : value - previousValue,
          fecha: DateTime.now(),
          nombreOperario: widget.currentUser.nombre,
          actorUid: widget.currentUser.uid,
          estado: 'editado_admin',
          conflictoId: null,
          detalleEstado: null,
          observacionesAdmin: _observationController.text.trim().isEmpty
              ? null
              : _observationController.text.trim(),
        );
      case 'propuesta':
      default:
        return widget.conflict.lecturaPropuesta.copyWith(
          lecturaAnterior: previousValue,
          consumoCalculado: previousValue == null
              ? null
              : widget.conflict.lecturaPropuesta.lecturaActual - previousValue,
          fecha: DateTime.now(),
          nombreOperario: widget.currentUser.nombre,
          actorUid: widget.currentUser.uid,
          estado: 'editado_admin',
          conflictoId: null,
          detalleEstado: null,
          observacionesAdmin: _observationController.text.trim().isEmpty
              ? null
              : _observationController.text.trim(),
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
      // TODO: migrate to RadioGroup once the surrounding dialog is refactored.
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
  const _ConflictResolutionResult(
    this.finalReading,
    this.adminObservation,
    this.warningMessage,
  );

  final ConsumptionReading finalReading;
  final String adminObservation;
  final String warningMessage;
}
