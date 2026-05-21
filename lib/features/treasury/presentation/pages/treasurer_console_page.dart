import 'package:flutter/material.dart';

import '../../../../theme/app_colors.dart';
import '../../../expenses/presentation/pages/expense_supports_page.dart';
import '../../../expenses/presentation/pages/expenses_page.dart';
import '../../../reports/presentation/pages/billing_reports_page.dart';
import '../../../reports/presentation/pages/consumption_reports_placeholder_page.dart';
import '../../../reports/presentation/pages/expense_reports_page.dart';
import '../../../reports/presentation/pages/extraordinary_reports_page.dart';
import '../../../reports/presentation/pages/portfolio_reports_page.dart';
import '../../../users/domain/app_user.dart';

class TreasurerConsolePage extends StatefulWidget {
  const TreasurerConsolePage({super.key, required this.currentUser});

  final AppUser currentUser;

  @override
  State<TreasurerConsolePage> createState() => _TreasurerConsolePageState();
}

class _TreasurerConsolePageState extends State<TreasurerConsolePage> {
  int _selectedModuleIndex = 0;
  final List<int> _selectedScreenIndexes = [0, 0];

  @override
  Widget build(BuildContext context) {
    final modules = _buildModules();
    final selectedModule = modules[_selectedModuleIndex];
    final selectedScreenIndex = _selectedScreenIndexes[_selectedModuleIndex]
        .clamp(0, selectedModule.screens.length - 1);
    final narrow = MediaQuery.sizeOf(context).width < 760;

    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TreasurerMenu(
            modules: modules,
            selectedModuleIndex: _selectedModuleIndex,
            selectedScreenIndexes: _selectedScreenIndexes,
            onSelected: _selectScreen,
          ),
          const SizedBox(height: 16),
          Expanded(child: selectedModule.screens[selectedScreenIndex].child),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 248,
          child: _TreasurerMenu(
            modules: modules,
            selectedModuleIndex: _selectedModuleIndex,
            selectedScreenIndexes: _selectedScreenIndexes,
            onSelected: _selectScreen,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(child: selectedModule.screens[selectedScreenIndex].child),
      ],
    );
  }

  void _selectScreen(int moduleIndex, int screenIndex) {
    setState(() {
      _selectedModuleIndex = moduleIndex;
      _selectedScreenIndexes[moduleIndex] = screenIndex;
    });
  }

  List<_TreasurerModule> _buildModules() {
    return [
      _TreasurerModule(
        title: 'Gastos',
        screens: [
          _TreasurerScreen(
            title: 'Gastos',
            child: ExpensesPage(currentUser: widget.currentUser),
          ),
          _TreasurerScreen(
            title: 'Soportes',
            child: ExpenseSupportsPage(currentUser: widget.currentUser),
          ),
        ],
      ),
      const _TreasurerModule(
        title: 'Reportes',
        screens: [
          _TreasurerScreen(title: 'Facturacion', child: BillingReportsPage()),
          _TreasurerScreen(
            title: 'Consumos',
            child: ConsumptionReportsPlaceholderPage(),
          ),
          _TreasurerScreen(title: 'Cartera', child: PortfolioReportsPage()),
          _TreasurerScreen(
            title: 'Extraordinarios',
            child: ExtraordinaryReportsPage(),
          ),
          _TreasurerScreen(title: 'Gastos', child: ExpenseReportsPage()),
        ],
      ),
    ];
  }
}

class _TreasurerModule {
  const _TreasurerModule({required this.title, required this.screens});

  final String title;
  final List<_TreasurerScreen> screens;
}

class _TreasurerScreen {
  const _TreasurerScreen({required this.title, required this.child});

  final String title;
  final Widget child;
}

class _TreasurerMenu extends StatelessWidget {
  const _TreasurerMenu({
    required this.modules,
    required this.selectedModuleIndex,
    required this.selectedScreenIndexes,
    required this.onSelected,
  });

  final List<_TreasurerModule> modules;
  final int selectedModuleIndex;
  final List<int> selectedScreenIndexes;
  final void Function(int moduleIndex, int screenIndex) onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var moduleIndex = 0;
                moduleIndex < modules.length;
                moduleIndex++) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                child: Text(
                  modules[moduleIndex].title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: moduleIndex == selectedModuleIndex
                            ? AppColors.brandBlue
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              for (var screenIndex = 0;
                  screenIndex < modules[moduleIndex].screens.length;
                  screenIndex++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _TreasurerMenuItem(
                    title: modules[moduleIndex].screens[screenIndex].title,
                    selected: moduleIndex == selectedModuleIndex &&
                        selectedScreenIndexes[moduleIndex] == screenIndex,
                    onTap: () => onSelected(moduleIndex, screenIndex),
                  ),
                ),
              if (moduleIndex != modules.length - 1)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TreasurerMenuItem extends StatelessWidget {
  const _TreasurerMenuItem({
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
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          title,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: selected ? AppColors.brandBlue : AppColors.textPrimary,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
        ),
      ),
    );
  }
}
