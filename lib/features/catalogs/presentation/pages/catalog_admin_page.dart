import 'package:flutter/material.dart';

import '../../../../core/presentation/text_formatters.dart';
import '../../../../theme/app_colors.dart';
import '../../data/catalog_firestore_service.dart';
import '../../domain/catalog_item.dart';

class CatalogAdminPage extends StatefulWidget {
  const CatalogAdminPage({
    super.key,
    required this.title,
    required this.description,
    required this.itemName,
    required this.valueLabel,
    required this.nameLabel,
    required this.service,
    this.autoValueFromName = false,
  });

  final String title;
  final String description;
  final String itemName;
  final String valueLabel;
  final String nameLabel;
  final CatalogFirestoreService service;
  final bool autoValueFromName;

  @override
  State<CatalogAdminPage> createState() => _CatalogAdminPageState();
}

class _CatalogAdminPageState extends State<CatalogAdminPage> {
  final TextEditingController _searchController = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CatalogItem>>(
      stream: widget.service.watchItems(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'No fue posible cargar ${widget.title.toLowerCase()}.',
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = snapshot.data!;
        final filtered = items.where((item) {
          final query = _search.trim().toLowerCase();
          if (query.isEmpty) {
            return true;
          }
          return item.valor.toLowerCase().contains(query) ||
              item.nombre.toLowerCase().contains(query) ||
              item.estado.toLowerCase().contains(query);
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(
              title: widget.title,
              description: widget.description,
              totalLabel: '${filtered.length}/${items.length}',
              onCreate: () => _openForm(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _search = value),
              decoration: const InputDecoration(
                labelText: 'Buscar',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No hay ${widget.title.toLowerCase()} para mostrar.',
                      ),
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        return _CatalogCard(
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

  Future<void> _openForm({CatalogItem? item}) async {
    final result = await showDialog<CatalogItem>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _CatalogItemDialog(
        item: item,
        valueLabel: widget.valueLabel,
        nameLabel: widget.nameLabel,
        itemName: widget.itemName,
        autoValueFromName: widget.autoValueFromName,
      ),
    );

    if (result == null) {
      return;
    }

    try {
      await widget.service.saveItem(result);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.itemName} guardado correctamente.')),
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

  Future<void> _delete(CatalogItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Eliminar ${widget.itemName}'),
        content: Text('Se eliminara ${toDisplayText(item.nombre)}.'),
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
      await widget.service.deleteItem(item.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.itemName} eliminado correctamente.')),
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
    required this.title,
    required this.description,
    required this.totalLabel,
    required this.onCreate,
  });

  final String title;
  final String description;
  final String totalLabel;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        final info = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(description, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 8),
            Text('Registros cargados: $totalLabel'),
          ],
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              info,
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Nuevo'),
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: info),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nuevo'),
            ),
          ],
        );
      },
    );
  }
}

class _CatalogItemDialog extends StatefulWidget {
  const _CatalogItemDialog({
    required this.valueLabel,
    required this.nameLabel,
    required this.itemName,
    required this.autoValueFromName,
    this.item,
  });

  final CatalogItem? item;
  final String valueLabel;
  final String nameLabel;
  final String itemName;
  final bool autoValueFromName;

  @override
  State<_CatalogItemDialog> createState() => _CatalogItemDialogState();
}

class _CatalogItemDialogState extends State<_CatalogItemDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _valueController;
  late final TextEditingController _nameController;
  String _estado = 'activo';

  bool get _isEditing => widget.item != null;

  @override
  void initState() {
    super.initState();
    _valueController = TextEditingController(text: widget.item?.valor ?? '');
    _nameController = TextEditingController(text: widget.item?.nombre ?? '');
    _estado = widget.item?.estado ?? 'activo';
  }

  @override
  void dispose() {
    _valueController.dispose();
    _nameController.dispose();
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
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isEditing
                        ? 'Editar ${widget.itemName}'
                        : 'Nuevo ${widget.itemName}',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(labelText: widget.nameLabel),
                    validator: _required,
                    onChanged: (value) {
                      if (widget.autoValueFromName && !_isEditing) {
                        _valueController.text = value.trim().toLowerCase();
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _valueController,
                    enabled: !widget.autoValueFromName,
                    decoration: InputDecoration(labelText: widget.valueLabel),
                    validator: _required,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _estado,
                    decoration: const InputDecoration(labelText: 'Estado'),
                    items: const [
                      DropdownMenuItem(value: 'activo', child: Text('Activo')),
                      DropdownMenuItem(value: 'inactivo', child: Text('Inactivo')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _estado = value);
                      }
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
    final value = _valueController.text.trim().toLowerCase();
    final normalizedId = _normalizeId(value);
    final item = CatalogItem(
      id: _isEditing ? widget.item!.id : normalizedId,
      valor: value,
      nombre: _nameController.text.trim().toLowerCase(),
      estado: _estado,
      fechaCreacion: widget.item?.fechaCreacion ?? now,
      fechaActualizacion: _isEditing ? now : null,
    );

    Navigator.of(context).pop(item);
  }

  String _normalizeId(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }
}

class _CatalogCard extends StatelessWidget {
  const _CatalogCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  final CatalogItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE0ECE8)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 640;
          final info = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                toDisplayText(item.nombre),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                '${toDisplayText(item.valor)} · ${toDisplayText(item.estado)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
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
              OutlinedButton.icon(
                onPressed: onDelete,
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
