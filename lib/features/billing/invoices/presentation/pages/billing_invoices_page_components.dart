part of 'billing_invoices_page.dart';

class _InvoiceSearchFieldSelector extends StatelessWidget {
  const _InvoiceSearchFieldSelector({
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

class _BillableReadingCard extends StatelessWidget {
  const _BillableReadingCard({required this.reading, required this.onGenerate});

  final ConsumptionReading reading;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    final previousReading = reading.lecturaAnterior ?? 0;
    final consumption =
        reading.consumoCalculado ??
        (reading.lecturaActual - previousReading).clamp(0, 1 << 31).toInt();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF8E9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEEDFA8)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              !constraints.hasBoundedWidth || constraints.maxWidth < 760;
          final info = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                toDisplayUserName(reading.nombreUsuario),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                'Pendiente por facturar - Codigo ${reading.codigoUsuario} - Contador ${reading.codigoContador}',
              ),
              const SizedBox(height: 6),
              Text(
                'Lectura anterior: $previousReading - Actual: ${reading.lecturaActual} - Consumo: $consumption m3',
              ),
            ],
          );
          final action = ElevatedButton.icon(
            onPressed: onGenerate,
            style: ElevatedButton.styleFrom(
              fixedSize: const Size(210, 48),
              minimumSize: const Size(210, 48),
              maximumSize: const Size(210, 48),
            ),
            icon: const Icon(Icons.receipt_rounded),
            label: const Text('Generar individual'),
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

// ignore: unused_element
class _Header extends StatelessWidget {
  const _Header({
    required this.periods,
    required this.selectedPeriod,
    required this.billableCount,
    required this.invoiceCount,
    required this.unpreparedCount,
    required this.onPeriodChanged,
    required this.onGenerate,
    required this.onRegenerate,
    required this.onExportPeriod,
    required this.onExportSector,
    required this.onShowUnprepared,
  });

  final List<BillingPeriod> periods;
  final BillingPeriod? selectedPeriod;
  final int billableCount;
  final int invoiceCount;
  final int unpreparedCount;
  final ValueChanged<BillingPeriod?> onPeriodChanged;
  final VoidCallback? onGenerate;
  final VoidCallback? onRegenerate;
  final VoidCallback? onExportPeriod;
  final VoidCallback? onExportSector;
  final VoidCallback? onShowUnprepared;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            !constraints.hasBoundedWidth || constraints.maxWidth < 760;
        final info = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Facturacion',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Selecciona un periodo y genera recibos para los consumos pendientes de facturar.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _Metric(label: 'Pendientes listos', value: '$billableCount'),
                _Metric(label: 'No preparados', value: '$unpreparedCount'),
                _Metric(label: 'Recibos', value: '$invoiceCount'),
              ],
            ),
          ],
        );
        final actions = Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 240,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Periodo',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<BillingPeriod>(
                    isExpanded: true,
                    initialValue: selectedPeriod,
                    decoration: const InputDecoration(
                      hintText: 'Selecciona un periodo',
                    ),
                    items: periods
                        .map(
                          (period) => DropdownMenuItem(
                            value: period,
                            child: Text(_periodLabel(period)),
                          ),
                        )
                        .toList(),
                    onChanged: onPeriodChanged,
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: onGenerate,
              style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
              icon: const Icon(Icons.receipt_long_rounded),
              label: const Text('Generar recibos'),
            ),
            OutlinedButton.icon(
              onPressed: onRegenerate,
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Regenerar'),
            ),
            OutlinedButton.icon(
              onPressed: onExportPeriod,
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              icon: const Icon(Icons.picture_as_pdf_rounded),
              label: const Text('PDF periodo'),
            ),
            OutlinedButton.icon(
              onPressed: onExportSector,
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              icon: const Icon(Icons.filter_alt_rounded),
              label: const Text('PDF por sector'),
            ),
            OutlinedButton.icon(
              onPressed: onShowUnprepared,
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              icon: const Icon(Icons.playlist_add_check_circle_outlined),
              label: const Text('No preparados'),
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
            actions,
          ],
        );
      },
    );
  }
}

class _InvoicePreviewCard extends StatelessWidget {
  const _InvoicePreviewCard({
    required this.invoice,
    required this.onPrint,
    required this.onRegenerate,
  });

  final Invoice invoice;
  final VoidCallback onPrint;
  final VoidCallback? onRegenerate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: onRegenerate,
                  style: OutlinedButton.styleFrom(
                    fixedSize: const Size(150, 44),
                    minimumSize: const Size(150, 44),
                    maximumSize: const Size(150, 44),
                  ),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Regenerar'),
                ),
                OutlinedButton.icon(
                  onPressed: onPrint,
                  style: OutlinedButton.styleFrom(
                    fixedSize: const Size(120, 44),
                    minimumSize: const Size(120, 44),
                    maximumSize: const Size(120, 44),
                  ),
                  icon: const Icon(Icons.picture_as_pdf_rounded),
                  label: const Text('PDF'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              _LabelValue(
                label: 'Codigo usuario',
                value: invoice.codigoUsuario,
              ),
              _LabelValue(label: 'Contador', value: invoice.codigoContador),
              _LabelValue(
                label: 'Usuario',
                value: toDisplayUserName(invoice.nombreUsuario),
              ),
              _LabelValue(label: 'Periodo facturado', value: invoice.periodo),
              _LabelValue(
                label: 'Generado',
                value: _formatDate(invoice.fechaGeneracion),
              ),
              _LabelValue(
                label: 'Vence',
                value: _formatDate(invoice.fechaVencimiento),
              ),
              _LabelValue(
                label: 'Consumo mes m3',
                value: '${invoice.consumoM3}',
              ),
              _LabelValue(
                label: 'Lectura anterior',
                value: '${invoice.lecturaAnterior ?? '-'}',
              ),
              _LabelValue(
                label: 'Lectura actual',
                value: '${invoice.lecturaActual}',
              ),
            ],
          ),
          if (invoice.saldoAnterior != 0) ...[
            const SizedBox(height: 14),
            Text(
              invoice.saldoAnterior < 0
                  ? 'Saldo a favor: ${_formatCurrency(invoice.saldoAnterior.abs())}'
                  : 'Saldo anterior: ${_formatCurrency(invoice.saldoAnterior)}',
            ),
          ],
          const SizedBox(height: 14),
          ...invoice.lineas.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(child: Text(item.descripcion)),
                  Text(
                    '${item.cantidad} x ${_formatCurrency(item.valorUnitario)}',
                  ),
                  const SizedBox(width: 14),
                  SizedBox(
                    width: 96,
                    child: Text(
                      _formatCurrency(item.valorTotal),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                child: Text('Estado: ${_receiptStatusDisplayText(invoice)}'),
              ),
              const SizedBox(width: 16),
              Text(
                'Total a pagar: ${_formatCurrency(invoice.totalAPagar)}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text('$label: $value'));
  }
}

class _HeaderPanel extends StatelessWidget {
  const _HeaderPanel({
    required this.periods,
    required this.selectedPeriod,
    required this.billableCount,
    required this.invoiceCount,
    required this.unpreparedCount,
    required this.onPeriodChanged,
    required this.onGenerate,
    required this.onRegenerate,
    required this.onExportPeriod,
    required this.onExportSector,
    required this.onShowUnprepared,
  });

  final List<BillingPeriod> periods;
  final BillingPeriod? selectedPeriod;
  final int billableCount;
  final int invoiceCount;
  final int unpreparedCount;
  final ValueChanged<BillingPeriod?> onPeriodChanged;
  final VoidCallback? onGenerate;
  final VoidCallback? onRegenerate;
  final VoidCallback? onExportPeriod;
  final VoidCallback? onExportSector;
  final VoidCallback? onShowUnprepared;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final periodValue = periods.contains(selectedPeriod)
            ? selectedPeriod
            : null;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Periodo de trabajo',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _Metric(label: 'Pendientes listos', value: '$billableCount'),
                  _Metric(label: 'Recibos', value: '$invoiceCount'),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<BillingPeriod>(
                isExpanded: true,
                initialValue: periodValue,
                decoration: const InputDecoration(
                  hintText: 'Selecciona un periodo',
                ),
                items: periods
                    .map(
                      (period) => DropdownMenuItem(
                        value: period,
                        child: Text(_periodLabel(period)),
                      ),
                    )
                    .toList(),
                onChanged: onPeriodChanged,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ElevatedButton.icon(
                    onPressed: onGenerate,
                    style: ElevatedButton.styleFrom(
                      fixedSize: const Size(190, 48),
                      minimumSize: const Size(190, 48),
                      maximumSize: const Size(190, 48),
                    ),
                    icon: const Icon(Icons.receipt_long_rounded),
                    label: const Text('Generar recibos'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onRegenerate,
                    style: OutlinedButton.styleFrom(
                      fixedSize: const Size(140, 48),
                      minimumSize: const Size(140, 48),
                      maximumSize: const Size(140, 48),
                    ),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Regenerar'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onExportPeriod,
                    style: OutlinedButton.styleFrom(
                      fixedSize: const Size(150, 48),
                      minimumSize: const Size(150, 48),
                      maximumSize: const Size(150, 48),
                    ),
                    icon: const Icon(Icons.picture_as_pdf_rounded),
                    label: const Text('PDF periodo'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onExportSector,
                    style: OutlinedButton.styleFrom(
                      fixedSize: const Size(160, 48),
                      minimumSize: const Size(160, 48),
                      maximumSize: const Size(160, 48),
                    ),
                    icon: const Icon(Icons.filter_alt_rounded),
                    label: const Text('PDF por sector'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onShowUnprepared,
                    style: OutlinedButton.styleFrom(
                      fixedSize: const Size(190, 48),
                      minimumSize: const Size(190, 48),
                      maximumSize: const Size(190, 48),
                    ),
                    icon: const Icon(Icons.playlist_add_check_circle_outlined),
                    label: Text('No preparados ($unpreparedCount)'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LabelValue extends StatelessWidget {
  const _LabelValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: 210, child: Text('$label: $value'));
  }
}

class _ExportInvoicesDialog extends StatefulWidget {
  const _ExportInvoicesDialog({
    required this.title,
    required this.description,
    this.sectors = const [],
  });

  final String title;
  final String description;
  final List<String> sectors;

  @override
  State<_ExportInvoicesDialog> createState() => _ExportInvoicesDialogState();
}

class _ExportInvoicesDialogState extends State<_ExportInvoicesDialog> {
  late String? _sector = widget.sectors.isEmpty ? null : widget.sectors.first;
  _PdfExportMode _mode = _PdfExportMode.combined;

  bool get _requiresSector => widget.sectors.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              Text(widget.description),
              if (_requiresSector) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _sector,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Sector'),
                  items: widget.sectors
                      .map(
                        (item) =>
                            DropdownMenuItem(value: item, child: Text(item)),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _sector = value),
                ),
              ],
              const SizedBox(height: 16),
              SegmentedButton<_PdfExportMode>(
                segments: const [
                  ButtonSegment(
                    value: _PdfExportMode.combined,
                    label: Text('Un solo PDF'),
                  ),
                  ButtonSegment(
                    value: _PdfExportMode.individual,
                    label: Text('Individuales'),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (selection) {
                  setState(() => _mode = selection.first);
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
                  FilledButton(
                    onPressed: _requiresSector && _sector == null
                        ? null
                        : () => Navigator.of(context).pop(
                            _ExportDialogResult(sector: _sector, mode: _mode),
                          ),
                    child: const Text('Exportar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExportDialogResult {
  const _ExportDialogResult({this.sector, required this.mode});

  final String? sector;
  final _PdfExportMode mode;
}

class _SectorExportResult {
  const _SectorExportResult({required this.sector, required this.mode});

  final String sector;
  final _PdfExportMode mode;
}

class _SectorExportDialog extends StatelessWidget {
  const _SectorExportDialog({required this.sectors});

  final List<String> sectors;

  @override
  Widget build(BuildContext context) {
    return _ExportInvoicesDialog(
      title: 'Exportar por sector',
      description:
          'Selecciona el sector y el formato de salida para los recibos del periodo.',
      sectors: sectors,
    );
  }
}

enum _PdfExportMode { combined, individual }

String _periodLabel(BillingPeriod period) {
  return '${period.clave} - ${toDisplayText(period.nombre)}${period.vigente ? ' - Vigente' : ''}';
}

String _receiptStatusDisplayText(Invoice invoice) {
  if (invoice.estaSuspendido) {
    // Cambio temporal solicitado: los recibos suspendidos se muestran como
    // "En mora" solo en la visualizacion del recibo. Para volver al texto
    // original, retornar toDisplayText(invoice.estado); no modificar el estado
    // interno "suspendido" ni el estado normal "en_mora".
    return 'En mora';
  }
  return toDisplayText(invoice.estadoPeriodoAnterior ?? invoice.estado);
}

String _formatDate(DateTime value) {
  return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
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
