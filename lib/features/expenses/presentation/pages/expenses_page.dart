import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/presentation/text_formatters.dart';
import '../../../../theme/app_colors.dart';
import '../../../billing/periods/data/billing_period_firestore_service.dart';
import '../../../billing/periods/domain/billing_period.dart';
import '../../../users/domain/app_user.dart';
import '../../data/expense_concept_firestore_service.dart';
import '../../data/expense_record_firestore_service.dart';
import '../../domain/expense_concept.dart';
import '../../domain/expense_record.dart';

class ExpensesPage extends StatefulWidget {
  const ExpensesPage({
    super.key,
    required this.currentUser,
    this.periodService,
    this.conceptService,
    this.expenseService,
  });

  final AppUser currentUser;
  final BillingPeriodFirestoreService? periodService;
  final ExpenseConceptFirestoreService? conceptService;
  final ExpenseRecordFirestoreService? expenseService;

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  late final BillingPeriodFirestoreService _periodService =
      widget.periodService ?? BillingPeriodFirestoreService();
  late final ExpenseConceptFirestoreService _conceptService =
      widget.conceptService ?? ExpenseConceptFirestoreService();
  late final ExpenseRecordFirestoreService _expenseService =
      widget.expenseService ?? ExpenseRecordFirestoreService();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  String _search = '';
  BillingPeriod? _selectedPeriod;
  List<BillingPeriod> _periods = const [];
  List<ExpenseConcept> _concepts = const [];
  final TextEditingController _searchController = TextEditingController();

  bool get _canEdit => widget.currentUser.rol == 'administrador';

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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _periodService.fetchOperationalPeriods(),
        _conceptService.fetchActiveItems(),
      ]);
      final periods = results[0] as List<BillingPeriod>;
      final concepts = results[1] as List<ExpenseConcept>;
      final selected = periods.isEmpty
          ? null
          : periods.firstWhere(
              (item) => item.vigente,
              orElse: () => periods.first,
            );
      if (!mounted) {
        return;
      }
      setState(() {
        _periods = periods;
        _concepts = concepts;
        _selectedPeriod = selected;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = '$error');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final period = _selectedPeriod;
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text('No fue posible cargar gastos: $_error'));
    }
    if (period == null) {
      return const Center(child: Text('No hay periodos disponibles.'));
    }

    return StreamBuilder<List<ExpenseRecord>>(
      stream: _expenseService.watchByPeriod(period.id),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('No fue posible cargar gastos.'));
        }
        final items = snapshot.data ?? const <ExpenseRecord>[];
        final filtered = _filter(items);
        final total = filtered.fold<int>(0, (sum, item) => sum + item.valor);

        return Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(
                  periods: _periods,
                  selectedPeriod: period,
                  totalLabel: '${filtered.length}/${items.length}',
                  totalAmount: total,
                  onPeriodChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedPeriod = value);
                    }
                  },
                  onCreate: () => _openForm(period: period),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _search = value),
                  decoration: const InputDecoration(
                    labelText:
                        'Buscar por concepto, beneficiario, identificacion o registrante',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: !snapshot.hasData
                      ? const Center(child: CircularProgressIndicator())
                      : filtered.isEmpty
                          ? const Center(
                              child: Text('No hay gastos para mostrar.'),
                            )
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final item = filtered[index];
                                return _ExpenseCard(
                                  item: item,
                                  canEdit: _canEdit,
                                  onEdit: () =>
                                      _openForm(period: period, item: item),
                                );
                              },
                            ),
                ),
              ],
            ),
            if (_saving)
              Positioned.fill(
                child: ColoredBox(
                  color: AppColors.textPrimary.withValues(alpha: 0.16),
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        );
      },
    );
  }

  List<ExpenseRecord> _filter(List<ExpenseRecord> items) {
    final query = _search.trim().toLowerCase();
    if (query.isEmpty) {
      return items;
    }
    return items.where((item) {
      return [
        item.conceptoNombre,
        item.pagadoANombre,
        item.pagadoAIdentificacion,
        item.registradoPorNombre,
      ].join(' ').toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _openForm({
    required BillingPeriod period,
    ExpenseRecord? item,
  }) async {
    if (item != null && !_canEdit) {
      return;
    }
    final result = await showDialog<_ExpenseFormResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ExpenseDialog(
        concepts: _concepts,
        existing: item,
      ),
    );
    if (result == null) {
      return;
    }

    setState(() => _saving = true);
    final now = DateTime.now();
    final expense = item == null
        ? ExpenseRecord(
            id: 'gasto_${now.microsecondsSinceEpoch}',
            periodoId: period.id,
            periodoNombre: period.nombre,
            conceptoId: result.concept.id,
            conceptoNombre: result.concept.nombre,
            valor: result.valor,
            fechaGasto: result.fechaGasto,
            pagadoANombre: result.pagadoANombre,
            pagadoAIdentificacion: result.pagadoAIdentificacion,
            registradoPorUid: widget.currentUser.uid,
            registradoPorNombre: widget.currentUser.nombre,
            fechaRegistro: now,
          )
        : item.copyWith(
            conceptoId: result.concept.id,
            conceptoNombre: result.concept.nombre,
            valor: result.valor,
            fechaGasto: result.fechaGasto,
            pagadoANombre: result.pagadoANombre,
            pagadoAIdentificacion: result.pagadoAIdentificacion,
            actualizadoPorUid: widget.currentUser.uid,
            actualizadoPorNombre: widget.currentUser.nombre,
            fechaActualizacion: now,
          );

    try {
      await _expenseService.saveItem(expense);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gasto guardado correctamente.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No fue posible guardar: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.periods,
    required this.selectedPeriod,
    required this.totalLabel,
    required this.totalAmount,
    required this.onPeriodChanged,
    required this.onCreate,
  });

  final List<BillingPeriod> periods;
  final BillingPeriod selectedPeriod;
  final String totalLabel;
  final int totalAmount;
  final ValueChanged<BillingPeriod?> onPeriodChanged;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 780;
        final title = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Gastos', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                Chip(label: Text('Registros: $totalLabel')),
                Chip(label: Text('Total: ${_formatCurrency(totalAmount)}')),
              ],
            ),
          ],
        );
        final controls = Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 280,
              child: DropdownButtonFormField<BillingPeriod>(
                isExpanded: true,
                initialValue: selectedPeriod,
                decoration: const InputDecoration(labelText: 'Periodo'),
                items: periods
                    .map(
                      (period) => DropdownMenuItem(
                        value: period,
                        child: Text(
                          _displayPeriod(period),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: onPeriodChanged,
              ),
            ),
            ElevatedButton.icon(
              onPressed: onCreate,
              style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nuevo gasto'),
            ),
          ],
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [title, const SizedBox(height: 12), controls],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: title),
            const SizedBox(width: 16),
            SizedBox(width: 420, child: controls),
          ],
        );
      },
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  const _ExpenseCard({
    required this.item,
    required this.canEdit,
    required this.onEdit,
  });

  final ExpenseRecord item;
  final bool canEdit;
  final VoidCallback onEdit;

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
          final compact = constraints.maxWidth < 760;
          final info = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    toDisplayText(item.conceptoNombre),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Chip(label: Text(_formatCurrency(item.valor))),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Fecha gasto: ${_formatDate(item.fechaGasto)}',
              ),
              const SizedBox(height: 6),
              Text(
                'Pagado a: ${toDisplayUserName(item.pagadoANombre)} - ${item.pagadoAIdentificacion}',
              ),
              const SizedBox(height: 6),
              Text(
                'Registrado por ${toDisplayUserName(item.registradoPorNombre)} - ${_formatDate(item.fechaRegistro)}',
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
          final action = canEdit
              ? OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('Editar'),
                )
              : const SizedBox.shrink();

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                info,
                if (canEdit) ...[const SizedBox(height: 12), action],
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: info),
              if (canEdit) ...[
                const SizedBox(width: 12),
                SizedBox(width: 140, child: action),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ExpenseDialog extends StatefulWidget {
  const _ExpenseDialog({
    required this.concepts,
    this.existing,
  });

  final List<ExpenseConcept> concepts;
  final ExpenseRecord? existing;

  @override
  State<_ExpenseDialog> createState() => _ExpenseDialogState();
}

class _ExpenseDialogState extends State<_ExpenseDialog> {
  final _formKey = GlobalKey<FormState>();
  late ExpenseConcept? _selectedConcept = _initialConcept();
  late DateTime _expenseDate = widget.existing?.fechaGasto ?? DateTime.now();
  late final TextEditingController _amountController = TextEditingController(
    text: widget.existing == null ? '' : '${widget.existing!.valor}',
  );
  late final TextEditingController _paidNameController = TextEditingController(
    text: widget.existing?.pagadoANombre ?? '',
  );
  late final TextEditingController _paidDocumentController =
      TextEditingController(text: widget.existing?.pagadoAIdentificacion ?? '');

  @override
  void dispose() {
    _amountController.dispose();
    _paidNameController.dispose();
    _paidDocumentController.dispose();
    super.dispose();
  }

  ExpenseConcept? _initialConcept() {
    final conceptId = widget.existing?.conceptoId;
    if (conceptId == null) {
      return widget.concepts.isEmpty ? null : widget.concepts.first;
    }
    for (final concept in widget.concepts) {
      if (concept.id == conceptId) {
        return concept;
      }
    }
    return widget.concepts.isEmpty ? null : widget.concepts.first;
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.existing == null ? 'Nuevo gasto' : 'Editar gasto',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<ExpenseConcept>(
                    isExpanded: true,
                    initialValue: _selectedConcept,
                    decoration: const InputDecoration(labelText: 'Concepto'),
                    items: widget.concepts
                        .map(
                          (concept) => DropdownMenuItem(
                            value: concept,
                            child: Text(
                              toDisplayText(concept.nombre),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _selectedConcept = value),
                    validator: (value) =>
                        value == null ? 'Selecciona un concepto.' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Valor'),
                    validator: (value) {
                      final amount = int.tryParse(value?.trim() ?? '');
                      if (amount == null || amount <= 0) {
                        return 'Ingresa un valor mayor a 0.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_month_rounded),
                    label: Text('Fecha gasto: ${_formatDate(_expenseDate)}'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _paidNameController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre a quien se pago',
                    ),
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? 'Ingresa el nombre.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _paidDocumentController,
                    decoration: const InputDecoration(
                      labelText: 'Identificacion a quien se pago',
                    ),
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? 'Ingresa la identificacion.'
                        : null,
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

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _expenseDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 2),
    );
    if (date != null) {
      setState(() => _expenseDate = date);
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate() || _selectedConcept == null) {
      return;
    }
    Navigator.of(context).pop(
      _ExpenseFormResult(
        concept: _selectedConcept!,
        valor: int.parse(_amountController.text.trim()),
        fechaGasto: _expenseDate,
        pagadoANombre: _paidNameController.text.trim(),
        pagadoAIdentificacion: _paidDocumentController.text.trim(),
      ),
    );
  }
}

class _ExpenseFormResult {
  const _ExpenseFormResult({
    required this.concept,
    required this.valor,
    required this.fechaGasto,
    required this.pagadoANombre,
    required this.pagadoAIdentificacion,
  });

  final ExpenseConcept concept;
  final int valor;
  final DateTime fechaGasto;
  final String pagadoANombre;
  final String pagadoAIdentificacion;
}

String _displayPeriod(BillingPeriod period) {
  final name = period.nombre.trim();
  if (name.isEmpty) {
    return period.id;
  }
  return '$name (${period.id})';
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
