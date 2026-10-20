part of 'billing_values_admin_page.dart';

class _BillingValueCard extends StatelessWidget {
  const _BillingValueCard({required this.item, required this.onEdit});

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
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                'Version ${item.version} - ${item.estado} - Aplica desde ${item.periodoInicio.isEmpty ? 'sin definir' : item.periodoInicio} - Actualizado por ${item.actorNombre}',
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
              if (item.valoresAdicionales.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  'Valores adicionales',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: item.valoresAdicionales
                      .map(
                        (value) => _RangeChip(
                          label:
                              '${value.periodoNombre.isEmpty ? value.periodoId : value.periodoNombre} - ${value.concepto} - ${value.isMassive ? 'Masivo' : value.codigoUsuario} - ${_formatCurrency(value.valor)}',
                        ),
                      )
                      .toList(),
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
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                icon: const Icon(Icons.edit_rounded),
                label: const Text('Actualizar'),
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [info, const SizedBox(height: 16), actions],
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
  }) : desdeController = TextEditingController(text: desde),
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

class _AdditionalValueFormRow {
  _AdditionalValueFormRow({
    this.periodoId,
    this.periodoNombre,
    this.isIndividual = false,
    String concepto = '',
    String codigoUsuario = '',
    String valor = '',
  }) : conceptoController = TextEditingController(text: concepto),
       codigoUsuarioController = TextEditingController(text: codigoUsuario),
       valorController = TextEditingController(text: valor);

  factory _AdditionalValueFormRow.fromValue(AdditionalBillingValue value) {
    return _AdditionalValueFormRow(
      periodoId: value.periodoId.isEmpty ? null : value.periodoId,
      periodoNombre: value.periodoNombre.isEmpty ? null : value.periodoNombre,
      isIndividual: !value.isMassive,
      concepto: value.concepto,
      codigoUsuario: value.codigoUsuario ?? '',
      valor: value.valor.toString(),
    );
  }

  String? periodoId;
  String? periodoNombre;
  bool isIndividual;
  final TextEditingController conceptoController;
  final TextEditingController codigoUsuarioController;
  final TextEditingController valorController;

  void dispose() {
    conceptoController.dispose();
    codigoUsuarioController.dispose();
    valorController.dispose();
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
