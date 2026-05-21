import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../core/presentation/text_formatters.dart';
import '../../../../theme/app_colors.dart';
import '../../../billing/periods/data/billing_period_firestore_service.dart';
import '../../../billing/periods/domain/billing_period.dart';
import '../../../users/domain/app_user.dart';
import '../../data/expense_support_service.dart';
import '../../domain/expense_support.dart';

class ExpenseSupportsPage extends StatefulWidget {
  const ExpenseSupportsPage({
    super.key,
    required this.currentUser,
    this.periodService,
    this.supportService,
  });

  final AppUser currentUser;
  final BillingPeriodFirestoreService? periodService;
  final ExpenseSupportService? supportService;

  @override
  State<ExpenseSupportsPage> createState() => _ExpenseSupportsPageState();
}

class _ExpenseSupportsPageState extends State<ExpenseSupportsPage> {
  late final BillingPeriodFirestoreService _periodService =
      widget.periodService ?? BillingPeriodFirestoreService();
  late final ExpenseSupportService _supportService =
      widget.supportService ?? ExpenseSupportService();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  BillingPeriod? _selectedPeriod;
  List<BillingPeriod> _periods = const [];

  bool get _isAdmin => widget.currentUser.rol == 'administrador';

  @override
  void initState() {
    super.initState();
    _loadPeriods();
  }

  Future<void> _loadPeriods() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final periods = await _periodService.fetchOperationalPeriods();
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
      return Center(child: Text('No fue posible cargar soportes: $_error'));
    }
    if (period == null) {
      return const Center(child: Text('No hay periodos disponibles.'));
    }

    return StreamBuilder<ExpenseSupport?>(
      stream: _supportService.watchByPeriod(period.id),
      builder: (context, snapshot) {
        final support = snapshot.data;
        return Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(
                  periods: _periods,
                  selectedPeriod: period,
                  support: support,
                  canReplace: _isAdmin,
                  onPeriodChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedPeriod = value);
                    }
                  },
                  onUpload: support == null ? () => _upload(period) : null,
                  onReplace: support != null && _isAdmin
                      ? () => _replace(support)
                      : null,
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: !snapshot.hasData && snapshot.connectionState == ConnectionState.waiting
                      ? const Center(child: CircularProgressIndicator())
                      : support == null
                          ? const Center(
                              child: Text(
                                'No hay soporte cargado para este periodo.',
                              ),
                            )
                          : _SupportDetails(support: support),
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

  Future<void> _upload(BillingPeriod period) async {
    final picked = await _pickPdf();
    if (picked == null) {
      return;
    }
    setState(() => _saving = true);
    try {
      await _supportService.createSupport(
        periodId: period.id,
        periodName: period.nombre,
        fileName: picked.name,
        bytes: picked.bytes!,
        actorUid: widget.currentUser.uid,
        actorName: widget.currentUser.nombre,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Soporte cargado correctamente.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No fue posible cargar el soporte: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _replace(ExpenseSupport support) async {
    final picked = await _pickPdf();
    if (picked == null) {
      return;
    }
    setState(() => _saving = true);
    try {
      await _supportService.replaceSupport(
        current: support,
        fileName: picked.name,
        bytes: picked.bytes!,
        actorUid: widget.currentUser.uid,
        actorName: widget.currentUser.nombre,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Soporte reemplazado correctamente.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No fue posible reemplazar: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<PlatformFile?> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: true,
    );
    final file = result?.files.single;
    if (file == null) {
      return null;
    }
    final isPdfName = file.name.toLowerCase().endsWith('.pdf');
    final bytes = file.bytes;
    final isPdfContent = bytes != null &&
        bytes.length >= 4 &&
        bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46;
    if (!isPdfName || !isPdfContent) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecciona un archivo PDF valido.')),
        );
      }
      return null;
    }
    return file;
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.periods,
    required this.selectedPeriod,
    required this.support,
    required this.canReplace,
    required this.onPeriodChanged,
    required this.onUpload,
    required this.onReplace,
  });

  final List<BillingPeriod> periods;
  final BillingPeriod selectedPeriod;
  final ExpenseSupport? support;
  final bool canReplace;
  final ValueChanged<BillingPeriod?> onPeriodChanged;
  final VoidCallback? onUpload;
  final VoidCallback? onReplace;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 780;
        final title = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Soportes', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Carga un PDF por periodo para respaldar los gastos registrados.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Chip(label: Text(support == null ? 'Sin soporte' : 'Soporte cargado')),
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
              onPressed: onUpload,
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('Cargar PDF'),
            ),
            if (support != null && canReplace)
              OutlinedButton.icon(
                onPressed: onReplace,
                icon: const Icon(Icons.swap_horiz_rounded),
                label: const Text('Reemplazar PDF'),
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

class _SupportDetails extends StatelessWidget {
  const _SupportDetails({required this.support});

  final ExpenseSupport support;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 760),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              support.fileName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Text('Periodo: ${support.periodoId}'),
            const SizedBox(height: 6),
            Text(
              'Cargado por ${toDisplayUserName(support.cargadoPorNombre)} - ${_formatDate(support.fechaCarga)}',
            ),
            if (support.fechaEdicion != null) ...[
              const SizedBox(height: 6),
              Text(
                'Editado por ${toDisplayUserName(support.editadoPorNombre ?? '')} - ${_formatDate(support.fechaEdicion!)}',
              ),
            ],
            const SizedBox(height: 12),
            SelectionArea(
              child: Text(
                support.downloadUrl,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
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
