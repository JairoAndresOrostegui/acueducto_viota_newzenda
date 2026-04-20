import 'package:flutter/material.dart';

import '../../../../../theme/app_colors.dart';
import '../../data/payment_method_firestore_service.dart';
import '../../domain/payment_method.dart';

class PaymentMethodsAdminPage extends StatefulWidget {
  const PaymentMethodsAdminPage({
    super.key,
    this.service,
  });

  final PaymentMethodFirestoreService? service;

  @override
  State<PaymentMethodsAdminPage> createState() => _PaymentMethodsAdminPageState();
}

class _PaymentMethodsAdminPageState extends State<PaymentMethodsAdminPage> {
  final TextEditingController _searchController = TextEditingController();
  late final PaymentMethodFirestoreService _service =
      widget.service ?? PaymentMethodFirestoreService();
  String _search = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PaymentMethod>>(
      stream: _service.watchItems(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('No fue posible cargar los medios de pago.'),
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
          return item.descripcion.toLowerCase().contains(query);
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
                labelText: 'Buscar por texto',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Text('No hay medios de pago para mostrar.'),
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        return _PaymentMethodCard(
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

  Future<void> _openForm({PaymentMethod? item}) async {
    final result = await showDialog<PaymentMethod>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _PaymentMethodDialog(item: item),
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
        const SnackBar(content: Text('Medio de pago guardado correctamente.')),
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

  Future<void> _delete(PaymentMethod item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar medio de pago'),
        content: const Text('Se eliminará este medio de pago.'),
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
        const SnackBar(content: Text('Medio de pago eliminado correctamente.')),
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
        Text('Medios de pago', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          'Registra instrucciones de pago en texto libre, por ejemplo banco, tipo de cuenta, número, titular, transferencia o efectivo.',
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
            label: const Text('Nuevo'),
          ),
        ),
      ],
    );
  }
}

class _PaymentMethodDialog extends StatefulWidget {
  const _PaymentMethodDialog({this.item});

  final PaymentMethod? item;

  @override
  State<_PaymentMethodDialog> createState() => _PaymentMethodDialogState();
}

class _PaymentMethodDialogState extends State<_PaymentMethodDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _descriptionController =
      TextEditingController(text: widget.item?.descripcion ?? '');

  bool get _isEditing => widget.item != null;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
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
                        ? 'Editar medio de pago'
                        : 'Nuevo medio de pago',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Usa un solo texto libre para describir el medio de pago completo.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 6,
                    minLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Descripción',
                      alignLabelWithHint: true,
                      hintText:
                          'Ejemplo: Bancolombia ahorro 123456789, titular Juan Pérez, Nequi 3001234567 o Pago en efectivo en oficina.',
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
    final description = _descriptionController.text.trim();
    final item = PaymentMethod(
      id: widget.item?.id ?? _buildId(now),
      descripcion: description,
      fechaCreacion: widget.item?.fechaCreacion ?? now,
      fechaActualizacion: _isEditing ? now : null,
    );

    Navigator.of(context).pop(item);
  }

  String _buildId(DateTime now) {
    return 'medio_pago_${now.microsecondsSinceEpoch}';
  }
}

class _PaymentMethodCard extends StatelessWidget {
  const _PaymentMethodCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  final PaymentMethod item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 640;
          final info = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Medio de pago',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(
                item.descripcion,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textPrimary,
                ),
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
