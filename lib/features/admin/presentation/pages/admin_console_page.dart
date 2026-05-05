import 'package:flutter/material.dart';
import 'package:frontacueductonewzenda/features/accounts/presentation/pages/account_payments_page.dart';
import 'package:frontacueductonewzenda/features/accounts/presentation/pages/accounts_overview_page.dart';
import 'package:frontacueductonewzenda/features/accounts/presentation/pages/extraordinary_values_page.dart';
import 'package:frontacueductonewzenda/features/billing/invoices/presentation/pages/billing_invoices_page.dart';
import 'package:frontacueductonewzenda/features/billing/observations/presentation/pages/billing_observations_admin_page.dart';
import 'package:frontacueductonewzenda/features/billing/payment_methods/presentation/pages/payment_methods_admin_page.dart';
import 'package:frontacueductonewzenda/features/billing/periods/presentation/pages/billing_periods_page.dart';
import 'package:frontacueductonewzenda/features/billing/values/presentation/pages/billing_values_admin_page.dart';
import 'package:frontacueductonewzenda/features/catalogs/presentation/pages/catalog_admin_page.dart';
import 'package:frontacueductonewzenda/features/consumptions/presentation/pages/consumption_conflicts_admin_page.dart';
import 'package:frontacueductonewzenda/features/consumptions/presentation/pages/consumption_import_page.dart';
import 'package:frontacueductonewzenda/features/consumptions/presentation/pages/consumption_suspensions_admin_page.dart';
import 'package:frontacueductonewzenda/features/consumptions/presentation/pages/consumption_register_page.dart';
import 'package:frontacueductonewzenda/features/reports/presentation/pages/billing_reports_page.dart';
import 'package:frontacueductonewzenda/features/reports/presentation/pages/consumption_reports_placeholder_page.dart';
import 'package:frontacueductonewzenda/features/reports/presentation/pages/portfolio_reports_page.dart';

import '../../../../theme/app_colors.dart';
import '../../../catalogs/data/catalog_firestore_service.dart';
import '../../../users/data/user_admin_functions_service.dart';
import '../../../users/data/user_audit_log_service.dart';
import '../../../users/data/user_firestore_service.dart';
import '../../../users/domain/app_user.dart';
import '../../../users/presentation/pages/user_logs_page.dart';
import '../../../users/presentation/pages/users_admin_page.dart';
import '../../../users/presentation/pages/users_import_page.dart';

class AdminConsolePage extends StatefulWidget {
  const AdminConsolePage({
    super.key,
    required this.currentUser,
    this.userService,
    this.userAdminFunctionsService,
    this.documentTypeService,
    this.roleService,
    this.sectorService,
    this.userAuditLogService,
  });

  final AppUser currentUser;
  final UserFirestoreService? userService;
  final UserAdminFunctionsService? userAdminFunctionsService;
  final DocumentTypeCatalogService? documentTypeService;
  final RoleCatalogService? roleService;
  final SectorCatalogService? sectorService;
  final UserAuditLogService? userAuditLogService;

  @override
  State<AdminConsolePage> createState() => _AdminConsolePageState();
}

class _AdminConsolePageState extends State<AdminConsolePage> {
  int _selectedModuleIndex = 0;
  final List<int> _selectedScreenIndexes = [0, 0, 0, 0, 0];

  @override
  Widget build(BuildContext context) {
    final modules = _buildModules();
    if (_selectedModuleIndex >= modules.length) {
      _selectedModuleIndex = 0;
    }
    final selectedModule = modules[_selectedModuleIndex];
    final selectedScreenIndex = _selectedScreenIndexes[_selectedModuleIndex]
        .clamp(0, selectedModule.screens.length - 1);

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow =
            constraints.hasBoundedWidth && constraints.maxWidth < 760;
        final sidebarWidth = narrow ? 184.0 : 248.0;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: sidebarWidth,
              child: _AdminSidebar(
                modules: modules,
                selectedModuleIndex: _selectedModuleIndex,
                selectedScreenIndexes: _selectedScreenIndexes,
                onSelected: (moduleIndex, screenIndex) {
                  setState(() {
                    _selectedModuleIndex = moduleIndex;
                    _selectedScreenIndexes[moduleIndex] = screenIndex;
                  });
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(child: selectedModule.screens[selectedScreenIndex].child),
          ],
        );
      },
    );
  }

  List<_AdminModule> _buildModules() {
    final userScreens = <_AdminScreen>[
      _AdminScreen(
        title: 'Usuarios',
        child: UsersAdminPage(
          currentUser: widget.currentUser,
          userService: widget.userService,
          adminFunctionsService: widget.userAdminFunctionsService,
          documentTypeService: widget.documentTypeService,
          roleService: widget.roleService,
          sectorService: widget.sectorService,
        ),
      ),
      _AdminScreen(
        title: 'Importar usuarios',
        child: UsersImportPage(
          currentUser: widget.currentUser,
          adminFunctionsService: widget.userAdminFunctionsService,
        ),
      ),
      if (widget.currentUser.superAdmin) ...[
        _AdminScreen(
          title: 'Tipos documento',
          child: CatalogAdminPage(
            title: 'Tipos de documento',
            description:
                'Catalogo usado por el formulario de usuarios. Solo se muestran activos fuera de este modulo.',
            itemName: 'tipo de documento',
            valueLabel: 'Valor BD',
            nameLabel: 'Nombre visible',
            service:
                widget.documentTypeService ?? DocumentTypeCatalogService(),
          ),
        ),
        _AdminScreen(
          title: 'Roles',
          child: CatalogAdminPage(
            title: 'Roles',
            description:
                'Catalogo de perfiles permitidos para usuarios administrables.',
            itemName: 'rol',
            valueLabel: 'Valor BD',
            nameLabel: 'Nombre visible',
            service: widget.roleService ?? RoleCatalogService(),
          ),
        ),
      ],
      _AdminScreen(
        title: 'Sectores',
        child: CatalogAdminPage(
          title: 'Sectores',
          description:
              'Solo se ofrecen sectores activos al crear o editar usuarios con rol cliente.',
          itemName: 'sector',
          valueLabel: 'Valor BD',
          nameLabel: 'Nombre visible',
          service: widget.sectorService ?? SectorCatalogService(),
          autoValueFromName: true,
        ),
      ),
      if (widget.currentUser.superAdmin)
        _AdminScreen(
          title: 'Logs',
          child: UserLogsPage(
            service: widget.userAuditLogService ?? UserAuditLogService(),
          ),
        ),
    ];

    return [
      _AdminModule(
        title: 'Usuarios',
        screens: userScreens,
      ),
      _AdminModule(
        title: 'Consumos',
        screens: [
          _AdminScreen(
            title: 'Conflictos',
            child: ConsumptionConflictsAdminPage(
              currentUser: widget.currentUser,
            ),
          ),
          _AdminScreen(
            title: 'Registrar consumos',
            child: ConsumptionRegisterPage(currentUser: widget.currentUser),
          ),
          const _AdminScreen(
            title: 'Importar consumos',
            child: ConsumptionImportPage(),
          ),
          _AdminScreen(
            title: 'Suspensiones',
            child: ConsumptionSuspensionsAdminPage(
              currentUser: widget.currentUser,
            ),
          ),
        ],
      ),
      _AdminModule(
        title: 'Cuentas',
        screens: [
          const _AdminScreen(title: 'Cuentas', child: AccountsOverviewPage()),
          const _AdminScreen(
            title: 'Registrar pagos',
            child: AccountPaymentsPage(),
          ),
          _AdminScreen(
            title: 'Extraordinarios',
            child: ExtraordinaryValuesPage(currentUser: widget.currentUser),
          ),
        ],
      ),
      _AdminModule(
        title: 'Facturacion',
        screens: [
          _AdminScreen(
            title: 'Facturacion',
            child: BillingInvoicesPage(currentUser: widget.currentUser),
          ),
          _AdminScreen(title: 'Periodos', child: BillingPeriodsPage()),
          _AdminScreen(
            title: 'Medios de pago',
            child: PaymentMethodsAdminPage(),
          ),
          _AdminScreen(
            title: 'Observaciones',
            child: BillingObservationsAdminPage(),
          ),
          _AdminScreen(
            title: 'Valores',
            child: BillingValuesAdminPage(currentUser: widget.currentUser),
          ),
        ],
      ),
      _AdminModule(
        title: 'Reportes',
        screens: const [
          _AdminScreen(
            title: 'Facturación',
            child: BillingReportsPage(),
          ),
          _AdminScreen(
            title: 'Consumos',
            child: ConsumptionReportsPlaceholderPage(),
          ),
          _AdminScreen(title: 'Cartera', child: PortfolioReportsPage()),
        ],
      ),
    ];
  }
}

class _AdminModule {
  const _AdminModule({required this.title, required this.screens});

  final String title;
  final List<_AdminScreen> screens;
}

class _AdminScreen {
  const _AdminScreen({required this.title, required this.child});

  final String title;
  final Widget child;
}

class _AdminSidebar extends StatefulWidget {
  const _AdminSidebar({
    required this.modules,
    required this.selectedModuleIndex,
    required this.selectedScreenIndexes,
    required this.onSelected,
  });

  final List<_AdminModule> modules;
  final int selectedModuleIndex;
  final List<int> selectedScreenIndexes;
  final void Function(int moduleIndex, int screenIndex) onSelected;

  @override
  State<_AdminSidebar> createState() => _AdminSidebarState();
}

class _AdminSidebarState extends State<_AdminSidebar> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _scrollController,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (
                var moduleIndex = 0;
                moduleIndex < widget.modules.length;
                moduleIndex++
              ) ...[
                _ModuleTitle(
                  title: widget.modules[moduleIndex].title,
                  selected: moduleIndex == widget.selectedModuleIndex,
                ),
                const SizedBox(height: 6),
                for (
                  var screenIndex = 0;
                  screenIndex < widget.modules[moduleIndex].screens.length;
                  screenIndex++
                )
                  _ScreenNavButton(
                    title:
                        widget.modules[moduleIndex].screens[screenIndex].title,
                    selected:
                        moduleIndex == widget.selectedModuleIndex &&
                        screenIndex ==
                            widget.selectedScreenIndexes[moduleIndex],
                    onTap: () => widget.onSelected(moduleIndex, screenIndex),
                  ),
                if (moduleIndex < widget.modules.length - 1)
                  const Divider(height: 24),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ModuleTitle extends StatelessWidget {
  const _ModuleTitle({required this.title, required this.selected});

  final String title;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: selected
            ? Theme.of(context).colorScheme.primary
            : AppColors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _ScreenNavButton extends StatelessWidget {
  const _ScreenNavButton({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected
            ? colorScheme.primary.withValues(alpha: 0.10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: selected ? colorScheme.primary : AppColors.textSecondary,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
