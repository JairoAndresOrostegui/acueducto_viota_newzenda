part of 'consumption_register_page.dart';

class _Header extends StatelessWidget {
  const _Header({
    required this.workingPeriod,
    required this.cachedClients,
    required this.pendingCount,
    required this.blockedCount,
    required this.irregularCount,
    required this.missingReadingsCount,
    required this.showPendingReadings,
    required this.showIrregularReadings,
    required this.onDownloadPeriod,
    required this.onUploadReadings,
    required this.onClearLocalReadings,
    required this.onTogglePendingReadings,
    required this.onToggleIrregularReadings,
  });

  final String? workingPeriod;
  final int cachedClients;
  final int pendingCount;
  final int blockedCount;
  final int irregularCount;
  final int missingReadingsCount;
  final bool showPendingReadings;
  final bool showIrregularReadings;
  final VoidCallback onDownloadPeriod;
  final VoidCallback onUploadReadings;
  final VoidCallback onClearLocalReadings;
  final VoidCallback onTogglePendingReadings;
  final VoidCallback onToggleIrregularReadings;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final info = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Registrar consumos',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'El operador trabaja con un período descargado. Ese período no cambia automáticamente aunque el administrador marque otro como vigente.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Período de trabajo: ${workingPeriod ?? 'Sin descargar'} - Clientes: $cachedClients - Pendientes por subir: $pendingCount - Sin lectura: $missingReadingsCount - Bloqueados: $blockedCount - Irregularidades: $irregularCount',
            ),
          ],
        );

        final actions = Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            ElevatedButton.icon(
              onPressed: onDownloadPeriod,
              style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
              icon: const Icon(Icons.download_rounded),
              label: const Text('Descargar período vigente'),
            ),
            OutlinedButton.icon(
              onPressed: onUploadReadings,
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              icon: const Icon(Icons.cloud_upload_rounded),
              label: const Text('Subir lecturas'),
            ),
            OutlinedButton.icon(
              onPressed: onClearLocalReadings,
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Borrar locales'),
            ),
            OutlinedButton.icon(
              onPressed: onTogglePendingReadings,
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              icon: Icon(
                showPendingReadings
                    ? Icons.list_alt_rounded
                    : Icons.pending_actions_rounded,
              ),
              label: Text(
                showPendingReadings
                    ? 'Ver todos'
                    : 'Lecturas pendientes ($missingReadingsCount)',
              ),
            ),
            OutlinedButton.icon(
              onPressed: onToggleIrregularReadings,
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              icon: Icon(
                showIrregularReadings
                    ? Icons.list_alt_rounded
                    : Icons.warning_amber_rounded,
              ),
              label: Text(
                showIrregularReadings
                    ? 'Ver todos'
                    : 'Irregularidades ($irregularCount)',
              ),
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
            const SizedBox(width: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: actions,
            ),
          ],
        );
      },
    );
  }
}

class _ReadingSearchFieldSelector extends StatelessWidget {
  const _ReadingSearchFieldSelector({
    required this.selected,
    required this.onChanged,
  });

  static const _options = [
    ('nombre', 'Nombre'),
    ('codigoUsuario', 'Codigo usuario'),
    ('contador', 'Codigo contador'),
  ];

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return RadioGroup<String>(
      groupValue: selected,
      onChanged: (value) {
        if (value != null) {
          onChanged(value);
        }
      },
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final option in _options)
            InkWell(
              onTap: () => onChanged(option.$1),
              borderRadius: BorderRadius.circular(20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Radio<String>(
                    value: option.$1,
                    visualDensity: VisualDensity.compact,
                  ),
                  Text(option.$2),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PendingReadingRow extends StatelessWidget {
  const _PendingReadingRow({
    required this.customer,
    required this.previousReading,
  });

  final ConsumptionCustomer customer;
  final ConsumptionReading? previousReading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          final values = [
            _PendingValue(
              label: 'Código usuario',
              value: customer.codigoUsuario,
            ),
            _PendingValue(
              label: 'Código contador',
              value: customer.codigoContador,
            ),
            _PendingValue(
              label: 'Lectura anterior',
              value: previousReading == null
                  ? 'Sin histórico'
                  : '${previousReading!.lecturaActual}',
            ),
            _PendingValue(
              label: 'Nombre',
              value: toDisplayUserName(customer.nombreUsuario),
            ),
            _PendingValue(
              label: 'Sector',
              value: _displaySector(customer.sector),
            ),
          ];

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: values
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: item,
                    ),
                  )
                  .toList(),
            );
          }

          return Row(
            children: values
                .map((item) => Expanded(child: item))
                .toList(growable: false),
          );
        },
      ),
    );
  }
}

class _PendingValue extends StatelessWidget {
  const _PendingValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 2),
        Text(value, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

class _ConsumptionCustomerCard extends StatelessWidget {
  const _ConsumptionCustomerCard({
    required this.customer,
    required this.activePeriod,
    required this.reading,
    required this.previousReading,
    required this.onRegister,
  });

  final ConsumptionCustomer customer;
  final String? activePeriod;
  final ConsumptionReading? reading;
  final ConsumptionReading? previousReading;
  final VoidCallback? onRegister;

  @override
  Widget build(BuildContext context) {
    final blocked = reading?.isBlocked ?? false;
    final irregular = reading?.hasIrregularity ?? false;
    final statusColor = blocked
        ? Colors.orange.shade800
        : irregular
        ? Colors.red.shade800
        : AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: blocked
              ? Colors.orange.shade200
              : irregular
              ? Colors.red.shade200
              : AppColors.border,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final info = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                toDisplayUserName(customer.nombreUsuario),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                'Código usuario: ${customer.codigoUsuario} - Contador: ${customer.codigoContador}',
              ),
              const SizedBox(height: 6),
              Text('Sector: ${_displaySector(customer.sector)}'),
              const SizedBox(height: 6),
              Text('Período de trabajo: ${activePeriod ?? 'Sin descargar'}'),
              const SizedBox(height: 6),
              Text(
                previousReading == null
                    ? 'Lectura anterior: sin histórico descargado'
                    : 'Lectura anterior: ${previousReading!.lecturaActual} (${previousReading!.periodoActual})',
              ),
              if (reading != null) ...[
                const SizedBox(height: 12),
                Text('Lectura actual: ${reading!.lecturaActual}'),
                if (reading!.consumoCalculado != null) ...[
                  const SizedBox(height: 4),
                  Text('Consumo calculado: ${reading!.consumoCalculado}'),
                ],
                const SizedBox(height: 4),
                Text(
                  'Estado: ${reading!.estado} - Operario: ${toDisplayUserName(reading!.nombreOperario)}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: statusColor),
                ),
                if ((reading!.observacionesOperario ?? '').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('Observación: ${reading!.observacionesOperario!}'),
                ],
                if (reading!.irregularidad != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Irregularidad: ${reading!.irregularidad!.tipo}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.red.shade800,
                    ),
                  ),
                ],
                if ((reading!.detalleEstado ?? '').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    reading!.detalleEstado!,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: statusColor),
                  ),
                ],
              ],
            ],
          );
          final action = ElevatedButton.icon(
            onPressed: onRegister,
            style: ElevatedButton.styleFrom(minimumSize: const Size(0, 44)),
            icon: Icon(
              reading == null ? Icons.edit_note_rounded : Icons.edit_rounded,
            ),
            label: Text(
              reading == null
                  ? 'Registrar lectura'
                  : 'Actualizar en dispositivo',
            ),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [info, const SizedBox(height: 16), action],
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
}

class _ReadingDialog extends StatefulWidget {
  const _ReadingDialog({
    required this.customer,
    required this.period,
    required this.currentUser,
    required this.previousReading,
    required this.existingReading,
  });

  final ConsumptionCustomer customer;
  final String period;
  final AppUser currentUser;
  final ConsumptionReading? previousReading;
  final ConsumptionReading? existingReading;

  @override
  State<_ReadingDialog> createState() => _ReadingDialogState();
}

class _ReadingDialogState extends State<_ReadingDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _readingController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  bool _reportIrregularity = false;
  String _irregularityType = 'contador_adulterado';

  @override
  void initState() {
    super.initState();
    final existing = widget.existingReading;
    if (existing != null) {
      _readingController.text = '${existing.lecturaActual}';
      _notesController.text = existing.observacionesOperario ?? '';
      _reportIrregularity = existing.irregularidad != null;
      _irregularityType = existing.irregularidad?.tipo ?? _irregularityType;
    }
  }

  @override
  void dispose() {
    _readingController.dispose();
    _notesController.dispose();
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
                children: [
                  Text(
                    'Registrar lectura',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 20),
                  Text('Período: ${widget.period}'),
                  const SizedBox(height: 8),
                  Text('Código usuario: ${widget.customer.codigoUsuario}'),
                  const SizedBox(height: 8),
                  Text('Código contador: ${widget.customer.codigoContador}'),
                  const SizedBox(height: 8),
                  Text(
                    'Usuario: ${toDisplayUserName(widget.customer.nombreUsuario)}',
                  ),
                  const SizedBox(height: 8),
                  Text('Sector: ${_displaySector(widget.customer.sector)}'),
                  const SizedBox(height: 8),
                  Text(
                    widget.previousReading == null
                        ? 'Sin histórico previo descargado'
                        : 'Lectura anterior: ${widget.previousReading!.lecturaActual} (${widget.previousReading!.periodoActual})',
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _readingController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Lectura actual',
                    ),
                    validator: (value) {
                      final parsed = int.tryParse(value?.trim() ?? '');
                      if (parsed == null) {
                        return 'Ingresa una lectura válida.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    value: _reportIrregularity,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Reportar irregularidad'),
                    subtitle: const Text(
                      'Úsalo cuando el contador esté dañado, adulterado o la lectura no sea confiable.',
                    ),
                    onChanged: (value) {
                      setState(() => _reportIrregularity = value);
                    },
                  ),
                  if (_reportIrregularity) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _irregularityType,
                      decoration: const InputDecoration(
                        labelText: 'Tipo de irregularidad',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'contador_adulterado',
                          child: Text('Contador adulterado'),
                        ),
                        DropdownMenuItem(
                          value: 'contador_danado',
                          child: Text('Contador dañado'),
                        ),
                        DropdownMenuItem(
                          value: 'lectura_menor_sospechosa',
                          child: Text('Lectura menor sospechosa'),
                        ),
                        DropdownMenuItem(
                          value: 'contador_inaccesible',
                          child: Text('Contador inaccesible'),
                        ),
                        DropdownMenuItem(
                          value: 'sin_lectura_visible',
                          child: Text('Sin lectura visible'),
                        ),
                        DropdownMenuItem(
                          value: 'fuga_o_anomalia',
                          child: Text('Fuga o anomalía'),
                        ),
                        DropdownMenuItem(value: 'otro', child: Text('Otro')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _irregularityType = value);
                        }
                      },
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _notesController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: _reportIrregularity
                          ? 'Observaciones de irregularidad'
                          : 'Observaciones',
                    ),
                    validator: (value) {
                      if (_reportIrregularity &&
                          (value?.trim().isEmpty ?? true)) {
                        return 'Describe la irregularidad.';
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
                        child: const Text('Guardar en dispositivo'),
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

    final now = DateTime.now();
    final previousValue = widget.previousReading?.lecturaActual;
    final currentValue = int.parse(_readingController.text.trim());
    final irregularity = !_reportIrregularity
        ? null
        : ConsumptionIrregularity(
            tipo: _irregularityType,
            descripcion: _notesController.text.trim(),
            reportadoPorUid: widget.currentUser.uid,
            reportadoPorNombre: widget.currentUser.nombre,
            fechaReporte: now,
            lecturaObservada: currentValue,
          );

    Navigator.of(context).pop(
      ConsumptionReading(
        id: '${widget.period}|${widget.customer.codigoContador}',
        codigoUsuario: widget.customer.codigoUsuario,
        codigoContador: widget.customer.codigoContador,
        nombreUsuario: widget.customer.nombreUsuario,
        sector: widget.customer.sector,
        lecturaActual: currentValue,
        periodoActual: widget.period,
        fecha: now,
        nombreOperario: widget.currentUser.nombre,
        actorUid: widget.currentUser.uid,
        estado: _reportIrregularity ? 'pendiente_revision' : 'pendiente_local',
        lecturaAnterior: previousValue,
        consumoCalculado: previousValue == null
            ? null
            : currentValue - previousValue,
        facturado: widget.existingReading?.facturado ?? false,
        pagado: widget.existingReading?.pagado ?? false,
        observacionesOperario: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        observacionesAdmin: widget.existingReading?.observacionesAdmin,
        reciboId: widget.existingReading?.reciboId,
        irregularidad: irregularity,
        conflictoId: null,
        detalleEstado: null,
      ),
    );
  }
}
