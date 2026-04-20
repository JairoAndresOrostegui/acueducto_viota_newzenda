import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../theme/app_colors.dart';
import '../../../../users/domain/app_user.dart';
import '../../data/billing_value_config_firestore_service.dart';
import '../../domain/billing_value_config.dart';

class BillingValuesAdminPage extends StatefulWidget {
  const BillingValuesAdminPage({
    super.key,
    required this.currentUser,
    this.service,
  });

  final AppUser currentUser;
  final BillingValueConfigFirestoreService? service;

  @override
  State<BillingValuesAdminPage> createState() => _BillingValuesAdminPageState();
}

class _BillingValuesAdminPageState extends State<BillingValuesAdminPage> {
  late final BillingValueConfigFirestoreService _service =
      widget.service ?? BillingValueConfigFirestoreService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<BillingValueConfig?>(
      stream: _service.watchActiveItem(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('No fue posible cargar los valores de facturación.'),
          );
        }
        if (!snapshot.hasData) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
        }

        final activeItem = snapshot.data;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              hasActiveConfig: activeItem != null,
              versionLabel: activeItem == null ? null : 'Versión ${activeItem.version}',
              onCreate: () => _openForm(item: activeItem),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: activeItem == null
                  ? const Center(
                      child: Text(
                        'Aún no hay una configuración activa de valores.',
                      ),
                    )
                  : ListView(
                      children: [
                        _BillingValueCard(
                          item: activeItem,
                          onEdit: () => _openForm(item: activeItem),
                        ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openForm({BillingValueConfig? item}) async {
    final result = await showDialog<BillingValueConfig>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _BillingValueDialog(
        item: item,
        currentUser: widget.currentUser,
      ),
    );

    if (result == null) {
      return;
    }

    try {
      await _service.saveNewVersion(
        item: result,
        previousActive: item,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configuración de valores actualizada correctamente.'),
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

}

class _Header extends StatelessWidget {
  const _Header({
    required this.hasActiveConfig,
    required this.versionLabel,
    required this.onCreate,
  });

  final bool hasActiveConfig;
  final String? versionLabel;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Valores',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Configura cargo fijo, valor por consumo en rangos y reconexión para la facturación.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 8),
        Text(
          hasActiveConfig
              ? 'Configuración vigente: ${versionLabel ?? 'Activa'}'
              : 'Sin configuración vigente.',
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: ElevatedButton.icon(
            onPressed: onCreate,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, 48),
            ),
            icon: Icon(hasActiveConfig ? Icons.edit_rounded : Icons.add_rounded),
            label: Text(hasActiveConfig ? 'Actualizar valores' : 'Crear valores'),
          ),
        ),
      ],
    );
  }
}

class _BillingValueDialog extends StatefulWidget {
  const _BillingValueDialog({
    required this.currentUser,
    this.item,
  });

  final BillingValueConfig? item;
  final AppUser currentUser;

  @override
  State<_BillingValueDialog> createState() => _BillingValueDialogState();
}

class _BillingValueDialogState extends State<_BillingValueDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _cargoFijoController;
  late final TextEditingController _reconexionController;
  late final List<_RangeFormRow> _rangeRows;

  bool get _isEditing => widget.item != null;

  @override
  void initState() {
    super.initState();
    _cargoFijoController = TextEditingController(
      text: widget.item?.cargoFijo.toString() ?? '',
    );
    _reconexionController = TextEditingController(
      text: widget.item?.reconexion.toString() ?? '',
    );
    _rangeRows = (widget.item?.rangos ?? const [])
        .map(_RangeFormRow.fromRange)
        .toList();
    if (_rangeRows.isEmpty) {
      _rangeRows.add(_RangeFormRow());
    }
  }

  @override
  void dispose() {
    _cargoFijoController.dispose();
    _reconexionController.dispose();
    for (final row in _rangeRows) {
      row.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
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
                        ? 'Editar configuración de valores'
                        : 'Nueva configuración de valores',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Define los valores base y los rangos de consumo. El último rango puede quedar sin límite superior.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      SizedBox(
                        width: 240,
                        child: _moneyField(
                          controller: _cargoFijoController,
                          label: 'Cargo fijo',
                        ),
                      ),
                      SizedBox(
                        width: 240,
                        child: _moneyField(
                          controller: _reconexionController,
                          label: 'Reconexión',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Rangos de consumo',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _addRange,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 44),
                        ),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Agregar rango'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ..._buildRangeRows(),
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

  List<Widget> _buildRangeRows() {
    return List<Widget>.generate(_rangeRows.length, (index) {
      final row = _rangeRows[index];
      return Padding(
        padding: EdgeInsets.only(bottom: index == _rangeRows.length - 1 ? 0 : 12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Rango ${index + 1}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (_rangeRows.length > 1)
                    IconButton(
                      onPressed: () => _removeRange(index),
                      icon: const Icon(Icons.delete_outline_rounded),
                      tooltip: 'Eliminar rango',
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 160,
                    child: _numberField(
                      controller: row.desdeController,
                      label: 'Desde',
                    ),
                  ),
                  SizedBox(
                    width: 160,
                    child: _numberField(
                      controller: row.hastaController,
                      label: 'Hasta',
                      optional: true,
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: _moneyField(
                      controller: row.valorUnitarioController,
                      label: 'Valor por unidad',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _moneyField({
    required TextEditingController controller,
    required String label,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(labelText: label),
      validator: _requiredNumeric,
    );
  }

  Widget _numberField({
    required TextEditingController controller,
    required String label,
    bool optional = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(labelText: label),
      validator: optional ? null : _requiredNumeric,
    );
  }

  String? _requiredNumeric(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'Campo obligatorio.';
    }
    if (int.tryParse(text) == null) {
      return 'Solo se permiten números.';
    }
    return null;
  }

  void _addRange() {
    setState(() => _rangeRows.add(_RangeFormRow()));
  }

  void _removeRange(int index) {
    final row = _rangeRows.removeAt(index);
    row.dispose();
    setState(() {});
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final ranges = <ConsumptionRange>[];
    for (final row in _rangeRows) {
      final desde = int.parse(row.desdeController.text.trim());
      final hastaText = row.hastaController.text.trim();
      final hasta = hastaText.isEmpty ? null : int.parse(hastaText);
      final valorUnitario = int.parse(row.valorUnitarioController.text.trim());

      ranges.add(
        ConsumptionRange(
          desde: desde,
          hasta: hasta,
          valorUnitario: valorUnitario,
        ),
      );
    }

    final validationError = _validateRanges(ranges);
    if (validationError != null) {
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Rangos inválidos'),
          content: Text(validationError),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      return;
    }

    final now = DateTime.now();
    final item = BillingValueConfig(
      id: _buildId(now),
      estado: 'activo',
      version: (widget.item?.version ?? 0) + 1,
      cargoFijo: int.parse(_cargoFijoController.text.trim()),
      reconexion: int.parse(_reconexionController.text.trim()),
      rangos: ranges,
      actorUid: widget.currentUser.uid,
      actorNombre: widget.currentUser.nombre,
      fechaCreacion: now,
      fechaActualizacion: null,
    );

    Navigator.of(context).pop(item);
  }

  String? _validateRanges(List<ConsumptionRange> ranges) {
    if (ranges.isEmpty) {
      return 'Debes agregar al menos un rango de consumo.';
    }

    final sorted = [...ranges]..sort((a, b) => a.desde.compareTo(b.desde));
    if (sorted.first.desde != 0) {
      return 'El primer rango debe iniciar en 0.';
    }

    for (var index = 0; index < sorted.length; index++) {
      final current = sorted[index];
      if (current.valorUnitario <= 0) {
        return 'Cada rango debe tener un valor por unidad mayor a 0.';
      }
      if (current.hasta != null && current.hasta! < current.desde) {
        return 'En cada rango, "Hasta" debe ser mayor o igual a "Desde".';
      }
      final isLast = index == sorted.length - 1;
      if (!isLast && current.hasta == null) {
        return 'Solo el último rango puede quedar sin límite superior.';
      }
      if (isLast) {
        break;
      }
      final next = sorted[index + 1];
      final currentHasta = current.hasta;
      if (currentHasta == null) {
        return 'No puede haber rangos después de uno sin límite superior.';
      }
      if (next.desde <= currentHasta) {
        return 'Los rangos no pueden solaparse. El rango que inicia en ${next.desde} interfiere con el anterior.';
      }
      final expectedNextStart = currentHasta + 1;
      if (next.desde != expectedNextStart) {
        return 'Los rangos deben ser consecutivos y sin huecos. Se esperaba que el siguiente iniciara en $expectedNextStart.';
      }
    }

    return null;
  }

  String _buildId(DateTime now) {
    return 'valor_facturacion_${now.microsecondsSinceEpoch}';
  }
}

class _BillingValueCard extends StatelessWidget {
  const _BillingValueCard({
    required this.item,
    required this.onEdit,
  });

  final BillingValueConfig item;
  final VoidCallback onEdit;

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
          final compact = constraints.maxWidth < 760;
          final info = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cargo fijo: ${_formatCurrency(item.cargoFijo)}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                'Reconexión: ${_formatCurrency(item.reconexion)}',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Versión ${item.version} · ${item.estado} · Actualizado por ${item.actorNombre}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: item.rangos
                    .map(
                      (range) => _RangeChip(
                        label:
                            '${range.desde}-${range.hasta ?? 'más'} · ${_formatCurrency(range.valorUnitario)}/u',
                      ),
                    )
                    .toList(),
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
                label: const Text('Actualizar'),
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

class _RangeChip extends StatelessWidget {
  const _RangeChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(label),
    );
  }
}

class _RangeFormRow {
  _RangeFormRow({
    String desde = '',
    String hasta = '',
    String valorUnitario = '',
  })  : desdeController = TextEditingController(text: desde),
        hastaController = TextEditingController(text: hasta),
        valorUnitarioController = TextEditingController(text: valorUnitario);

  factory _RangeFormRow.fromRange(ConsumptionRange range) {
    return _RangeFormRow(
      desde: range.desde.toString(),
      hasta: range.hasta?.toString() ?? '',
      valorUnitario: range.valorUnitario.toString(),
    );
  }

  final TextEditingController desdeController;
  final TextEditingController hastaController;
  final TextEditingController valorUnitarioController;

  void dispose() {
    desdeController.dispose();
    hastaController.dispose();
    valorUnitarioController.dispose();
  }
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
