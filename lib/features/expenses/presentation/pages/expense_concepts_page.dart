import 'package:flutter/material.dart';

import '../../../../core/presentation/text_formatters.dart';
import '../../../../theme/app_colors.dart';
import '../../../users/domain/app_user.dart';
import '../../data/expense_concept_firestore_service.dart';
import '../../domain/expense_concept.dart';

class ExpenseConceptsPage extends StatefulWidget {
  const ExpenseConceptsPage({
    super.key,
    required this.currentUser,
    this.service,
  });

  final AppUser currentUser;
  final ExpenseConceptFirestoreService? service;

  @override
  State<ExpenseConceptsPage> createState() => _ExpenseConceptsPageState();
}

class _ExpenseConceptsPageState extends State<ExpenseConceptsPage> {
  late final ExpenseConceptFirestoreService _service =
      widget.service ?? ExpenseConceptFirestoreService();
  final TextEditingController _searchController = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ExpenseConcept>>(
      stream: _service.watchItems(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text('No fue posible cargar los conceptos.'),
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
          return [
            item.nombre,
            item.descripcion,
            item.estado,
            item.creadoPorNombre,
            item.actualizadoPorNombre ?? '',
          ].join(' ').toLowerCase().contains(query);
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
                labelText: 'Buscar por nombre, descripcion o estado',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Text('No hay conceptos para mostrar.'),
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        return _ConceptCard(
                          item: item,
                          onEdit: () => _openForm(item: item),
                          onToggle: () => _toggleStatus(item),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openForm({ExpenseConcept? item}) async {
    final result = await showDialog<_ConceptFormResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ConceptDialog(item: item),
    );
    if (result == null) {
      return;
    }

    final now = DateTime.now();
    final concept = item == null
        ? ExpenseConcept(
            id: _conceptId(result.nombre, now),
            nombre: result.nombre,
            descripcion: result.descripcion,
            estado: 'activo',
            creadoPorUid: widget.currentUser.uid,
            creadoPorNombre: widget.currentUser.nombre,
            fechaCreacion: now,
          )
        : item.copyWith(
            nombre: result.nombre,
            descripcion: result.descripcion,
            actualizadoPorUid: widget.currentUser.uid,
            actualizadoPorNombre: widget.currentUser.nombre,
            fechaActualizacion: now,
          );

    try {
      await _service.saveItem(concept);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Concepto guardado correctamente.')),
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

  Future<void> _toggleStatus(ExpenseConcept item) async {
    final newStatus = item.activo ? 'inactivo' : 'activo';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item.activo ? 'Inhabilitar concepto' : 'Habilitar concepto'),
        content: Text(
          item.activo
              ? 'El concepto no se mostrara para registrar gastos.'
              : 'El concepto volvera a estar disponible para registrar gastos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(item.activo ? 'Inhabilitar' : 'Habilitar'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    final updated = item.copyWith(
      estado: newStatus,
      actualizadoPorUid: widget.currentUser.uid,
      actualizadoPorNombre: widget.currentUser.nombre,
      fechaActualizacion: DateTime.now(),
    );

    try {
      await _service.saveItem(updated);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            updated.activo ? 'Concepto habilitado.' : 'Concepto inhabilitado.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No fue posible actualizar: $error')),
      );
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.totalLabel, required this.onCreate});

  final String totalLabel;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Conceptos', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          'Administra los conceptos disponibles para registrar gastos.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 8),
        Text('Registros cargados: $totalLabel'),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: ElevatedButton.icon(
            onPressed: onCreate,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, 48),
            ),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Nuevo concepto'),
          ),
        ),
      ],
    );
  }
}

class _ConceptCard extends StatelessWidget {
  const _ConceptCard({
    required this.item,
    required this.onEdit,
    required this.onToggle,
  });

  final ExpenseConcept item;
  final VoidCallback onEdit;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
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
                  Text(
                    toDisplayText(item.nombre),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Chip(
                    label: Text(item.activo ? 'Activo' : 'Inactivo'),
                    backgroundColor:
                        item.activo ? AppColors.brandGreenSoft : null,
                  ),
                ],
              ),
              if (item.descripcion.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(item.descripcion),
              ],
              const SizedBox(height: 8),
              Text(
                'Creado por ${toDisplayUserName(item.creadoPorNombre)} - ${_formatDate(item.fechaCreacion)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (item.fechaActualizacion != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Actualizado por ${toDisplayUserName(item.actualizadoPorNombre ?? '')} - ${_formatDate(item.fechaActualizacion!)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          );
          final actions = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_rounded),
                label: const Text('Editar'),
              ),
              FilledButton.icon(
                onPressed: onToggle,
                icon: Icon(
                  item.activo
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                ),
                label: Text(item.activo ? 'Inhabilitar' : 'Habilitar'),
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [info, const SizedBox(height: 12), actions],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: info),
              const SizedBox(width: 12),
              SizedBox(width: 280, child: actions),
            ],
          );
        },
      ),
    );
  }
}

class _ConceptDialog extends StatefulWidget {
  const _ConceptDialog({this.item});

  final ExpenseConcept? item;

  @override
  State<_ConceptDialog> createState() => _ConceptDialogState();
}

class _ConceptDialogState extends State<_ConceptDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController =
      TextEditingController(text: widget.item?.nombre ?? '');
  late final TextEditingController _descriptionController =
      TextEditingController(text: widget.item?.descripcion ?? '');

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.item == null ? 'Nuevo concepto' : 'Editar concepto',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Nombre'),
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? 'Ingresa el nombre.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionController,
                    decoration:
                        const InputDecoration(labelText: 'Descripcion'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.end,
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

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    Navigator.of(context).pop(
      _ConceptFormResult(
        nombre: _nameController.text.trim(),
        descripcion: _descriptionController.text.trim(),
      ),
    );
  }
}

class _ConceptFormResult {
  const _ConceptFormResult({
    required this.nombre,
    required this.descripcion,
  });

  final String nombre;
  final String descripcion;
}

String _conceptId(String name, DateTime now) {
  final normalized = name
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  final base = normalized.isEmpty ? 'concepto' : normalized;
  return '${base}_${now.microsecondsSinceEpoch}';
}

String _formatDate(DateTime value) {
  return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}
