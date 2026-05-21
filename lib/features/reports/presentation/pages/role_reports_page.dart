import 'package:flutter/material.dart';

import '../../../../theme/app_colors.dart';
import '../../../consumptions/presentation/pages/consumption_reports_admin_page.dart';
import 'expense_reports_page.dart';
import 'extraordinary_reports_page.dart';

class RoleReportsPage extends StatefulWidget {
  const RoleReportsPage({super.key});

  @override
  State<RoleReportsPage> createState() => _RoleReportsPageState();
}

class _RoleReportsPageState extends State<RoleReportsPage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = const [
      _ReportScreen(
        title: 'Consumos',
        child: ConsumptionReportsAdminPage(),
      ),
      _ReportScreen(
        title: 'Extraordinarios',
        child: ExtraordinaryReportsPage(),
      ),
      _ReportScreen(
        title: 'Gastos',
        child: ExpenseReportsPage(),
      ),
    ];
    final compact = MediaQuery.sizeOf(context).width < 760;

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ReportsMenu(
            screens: screens,
            selectedIndex: _selectedIndex,
            onSelected: (index) => setState(() => _selectedIndex = index),
          ),
          const SizedBox(height: 16),
          Expanded(child: screens[_selectedIndex].child),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 248,
          child: _ReportsMenu(
            screens: screens,
            selectedIndex: _selectedIndex,
            onSelected: (index) => setState(() => _selectedIndex = index),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(child: screens[_selectedIndex].child),
      ],
    );
  }
}

class _ReportScreen {
  const _ReportScreen({required this.title, required this.child});

  final String title;
  final Widget child;
}

class _ReportsMenu extends StatelessWidget {
  const _ReportsMenu({
    required this.screens,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<_ReportScreen> screens;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Text(
              'Reportes',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          for (var index = 0; index < screens.length; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _ReportMenuItem(
                title: screens[index].title,
                selected: selectedIndex == index,
                onTap: () => onSelected(index),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReportMenuItem extends StatelessWidget {
  const _ReportMenuItem({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.brandBlue.withValues(alpha: 0.12)
              : null,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(
              Icons.insert_chart_outlined_rounded,
              size: 20,
              color: selected ? AppColors.brandBlue : AppColors.textSecondary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: selected
                          ? AppColors.brandBlue
                          : AppColors.textPrimary,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
