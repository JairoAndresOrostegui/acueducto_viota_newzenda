import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../../theme/app_colors.dart';
import '../../data/billing_period_firestore_service.dart';
import '../../domain/billing_period.dart';

class BillingPeriodsPage extends StatefulWidget {
  const BillingPeriodsPage({
    super.key,
    this.service,
  });

  final BillingPeriodFirestoreService? service;

  @override
  State<BillingPeriodsPage> createState() => _BillingPeriodsPageState();
}

class _BillingPeriodsPageState extends State<BillingPeriodsPage> {
  static const int _startYear = 2025;

  late final BillingPeriodFirestoreService _service =
      widget.service ?? BillingPeriodFirestoreService();

  late int _selectedYear = _availableYears.first;
  bool _isSaving = false;

  List<int> get _availableYears {
    final currentYear = DateTime.now().year;
    return List<int>.generate(
      currentYear - _startYear + 1,
      (index) => currentYear - index,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        StreamBuilder<List<BillingPeriod>>(
          stream: _service.watchPeriods(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _ErrorState(message: snapshot.error.toString());
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final periods = snapshot.data!;
            final currentPeriod = periods.cast<BillingPeriod?>().firstWhere(
                  (item) => item?.vigente == true,
                  orElse: () => null,
                );
            final selectedPeriods = periods
                .where((period) => period.ano == _selectedYear)
                .toList();
            final allowedMonths = _allowedMonthsForYear(_selectedYear);
            final generatedMonths = selectedPeriods.map((item) => item.mes).toSet();
            final missingMonths = allowedMonths
                .where((month) => !generatedMonths.contains(month))
                .toList();

            return AbsorbPointer(
              absorbing: _isSaving,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PeriodsHeader(
                    totalGenerated: periods.length,
                    selectedYear: _selectedYear,
                    yearGenerated: generatedMonths.length,
                    yearAvailable: allowedMonths.length,
                    currentPeriodName: currentPeriod?.nombre,
                    onCreateMissing: missingMonths.isEmpty
                        ? null
                        : () => _createMissingPeriods(
                              year: _selectedYear,
                              months: missingMonths,
                            ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 54,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _availableYears.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final year = _availableYears[index];
                        final isSelected = year == _selectedYear;
                        return _YearChip(
                          year: year,
                          isSelected: isSelected,
                          onTap: () => setState(() => _selectedYear = year),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _MetricCard(
                        label: 'Años habilitados',
                        value: '${_availableYears.length}',
                        color: AppColors.brandBlueSoft,
                      ),
                      _MetricCard(
                        label: 'Períodos generados',
                        value: '${periods.length}',
                        color: AppColors.brandGreenSoft,
                      ),
                      _MetricCard(
                        label: 'Pendientes del año',
                        value: '${missingMonths.length}',
                        color: const Color(0xFFFDF1DA),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: const [
                        _LegendDot(
                          color: AppColors.brandGreenSoft,
                          label: 'Generado en el sistema',
                        ),
                        SizedBox(width: 18),
                        _LegendDot(
                          color: AppColors.brandBlueSoft,
                          label: 'Disponible por generar',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 260,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.0,
                      ),
                      itemCount: allowedMonths.length,
                      itemBuilder: (context, index) {
                        final month = allowedMonths[index];
                        final period = selectedPeriods.cast<BillingPeriod?>().firstWhere(
                              (item) => item?.mes == month,
                              orElse: () => null,
                            );
                        return _MonthCard(
                          year: _selectedYear,
                          month: month,
                          period: period,
                          isCurrent: period?.vigente == true,
                          onCreate: period != null
                              ? null
                              : () => _createSinglePeriod(
                                    year: _selectedYear,
                                    month: month,
                                  ),
                          onSetCurrent: period == null || period.vigente
                              ? null
                              : () => _setCurrentPeriod(period),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        if (_isSaving)
          Positioned.fill(
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: ColoredBox(
                  color: AppColors.textPrimary.withValues(alpha: 0.18),
                  child: const Center(child: _SavingOverlay()),
                ),
              ),
            ),
          ),
      ],
    );
  }

  List<int> _allowedMonthsForYear(int year) {
    final now = DateTime.now();
    if (year < now.year) {
      return List<int>.generate(12, (index) => index + 1);
    }

    final maxMonth = now.month == 12 ? 12 : now.month + 1;
    return List<int>.generate(maxMonth, (index) => index + 1);
  }

  Future<void> _createSinglePeriod({
    required int year,
    required int month,
  }) async {
    await _runSave(
      action: () => _service.createPeriod(ano: year, mes: month),
      successMessage:
          'Período ${BillingPeriodFirestoreService.periodName(year, month)} generado correctamente.',
    );
  }

  Future<void> _createMissingPeriods({
    required int year,
    required List<int> months,
  }) async {
    await _runSave(
      action: () => _service.createPeriodsForYear(ano: year, meses: months),
      successMessage:
          'Se generaron ${months.length} períodos faltantes para $year.',
    );
  }

  Future<void> _setCurrentPeriod(BillingPeriod period) async {
    await _runSave(
      action: () => _service.setCurrentPeriod(period.id),
      successMessage:
          'Período ${BillingPeriodFirestoreService.periodName(period.ano, period.mes)} marcado como vigente.',
    );
  }

  Future<void> _runSave({
    required Future<void> Function() action,
    required String successMessage,
  }) async {
    try {
      setState(() => _isSaving = true);
      await action();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No fue posible generar el período: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}

class _PeriodsHeader extends StatelessWidget {
  const _PeriodsHeader({
    required this.totalGenerated,
    required this.selectedYear,
    required this.yearGenerated,
    required this.yearAvailable,
    required this.currentPeriodName,
    required this.onCreateMissing,
  });

  final int totalGenerated;
  final int selectedYear;
  final int yearGenerated;
  final int yearAvailable;
  final String? currentPeriodName;
  final VoidCallback? onCreateMissing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final info = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Períodos', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Genera períodos mensuales desde 2025 hasta el año actual. Los períodos existentes solo se consultan; no se editan ni se eliminan.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Año seleccionado: $selectedYear · Generados: $yearGenerated/$yearAvailable · Total sistema: $totalGenerated',
            ),
            if (currentPeriodName != null) ...[
              const SizedBox(height: 6),
              Text('Período vigente: ${_displayName(currentPeriodName!)}'),
            ],
          ],
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              info,
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onCreateMissing,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                ),
                icon: const Icon(Icons.calendar_month_rounded),
                label: const Text('Generar faltantes'),
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: info),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              onPressed: onCreateMissing,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 48),
              ),
              icon: const Icon(Icons.calendar_month_rounded),
              label: const Text('Generar faltantes'),
            ),
          ],
        );
      },
    );
  }

  String _displayName(String value) {
    final parts = value.split(' ');
    if (parts.isEmpty) {
      return value;
    }
    return '${parts.first[0].toUpperCase()}${parts.first.substring(1)} ${parts.length > 1 ? parts[1] : ''}'
        .trim();
  }
}

class _YearChip extends StatelessWidget {
  const _YearChip({
    required this.year,
    required this.isSelected,
    required this.onTap,
  });

  final int year;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? AppColors.brandBlue : AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected ? AppColors.brandBlue : AppColors.border,
            ),
          ),
          child: Text(
            '$year',
            style: TextStyle(
              color: isSelected ? AppColors.textOnDark : AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          Text(value, style: Theme.of(context).textTheme.headlineMedium),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({
    required this.color,
    required this.label,
  });

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border),
          ),
        ),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }
}

class _MonthCard extends StatelessWidget {
  const _MonthCard({
    required this.year,
    required this.month,
    required this.period,
    required this.isCurrent,
    required this.onCreate,
    required this.onSetCurrent,
  });

  final int year;
  final int month;
  final BillingPeriod? period;
  final bool isCurrent;
  final VoidCallback? onCreate;
  final VoidCallback? onSetCurrent;

  bool get _isGenerated => period != null;

  @override
  Widget build(BuildContext context) {
    final periodName = BillingPeriodFirestoreService.periodName(year, month);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _isGenerated ? AppColors.brandGreenSoft : AppColors.brandBlueSoft,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _isGenerated ? AppColors.brandGreen : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            periodName.split(' ').first[0].toUpperCase() +
                periodName.split(' ').first.substring(1),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            _isGenerated ? 'Generado' : 'Disponible por generar',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const Spacer(),
          if (_isGenerated) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatusBadge(
                  label: BillingPeriodFirestoreService.docId(year, month),
                  color: AppColors.brandGreenDark,
                ),
                if (isCurrent)
                  const _StatusBadge(
                    label: 'Vigente',
                    color: AppColors.brandBlueDark,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Bloqueado para edición y eliminación.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onSetCurrent,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 40),
                foregroundColor: isCurrent
                    ? AppColors.brandBlueDark
                    : AppColors.brandGreenDark,
              ),
              icon: Icon(
                isCurrent
                    ? Icons.verified_rounded
                    : Icons.radio_button_checked_rounded,
              ),
              label: Text(
                isCurrent ? 'Período vigente' : 'Marcar vigente',
              ),
            ),
          ] else
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                onPressed: onCreate,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 40),
                ),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Generar'),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'No fue posible cargar períodos.\n$message',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _SavingOverlay extends StatelessWidget {
  const _SavingOverlay();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(),
          ),
          SizedBox(height: 16),
          Text('Generando períodos...'),
        ],
      ),
    );
  }
}
