import 'package:flutter/material.dart';

import '../../../catalogs/data/catalog_firestore_service.dart';
import '../../../catalogs/presentation/pages/catalog_admin_page.dart';
import '../../../../theme/app_colors.dart';
import '../../../users/data/user_admin_functions_service.dart';
import '../../../users/data/user_audit_log_service.dart';
import '../../../users/data/user_firestore_service.dart';
import '../../../users/domain/app_user.dart';
import '../../../users/presentation/pages/user_logs_page.dart';
import '../../../users/presentation/pages/users_admin_page.dart';

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
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(28),
            ),
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: Theme.of(context).colorScheme.primary,
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'Usuarios'),
                Tab(text: 'Tipos documento'),
                Tab(text: 'Roles'),
                Tab(text: 'Sectores'),
                Tab(text: 'Logs'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: TabBarView(
              children: [
                UsersAdminPage(
                  currentUser: widget.currentUser,
                  userService: widget.userService,
                  adminFunctionsService: widget.userAdminFunctionsService,
                  documentTypeService: widget.documentTypeService,
                  roleService: widget.roleService,
                  sectorService: widget.sectorService,
                ),
                CatalogAdminPage(
                  title: 'Tipos de documento',
                  description:
                      'Catalogo usado por el formulario de usuarios. Solo se muestran activos fuera de este modulo.',
                  itemName: 'tipo de documento',
                  valueLabel: 'Valor BD',
                  nameLabel: 'Nombre visible',
                  service: widget.documentTypeService ?? DocumentTypeCatalogService(),
                ),
                CatalogAdminPage(
                  title: 'Roles',
                  description:
                      'Catalogo de perfiles permitidos para usuarios administrables.',
                  itemName: 'rol',
                  valueLabel: 'Valor BD',
                  nameLabel: 'Nombre visible',
                  service: widget.roleService ?? RoleCatalogService(),
                ),
                CatalogAdminPage(
                  title: 'Sectores',
                  description:
                      'Solo se ofrecen sectores activos al crear o editar usuarios con rol cliente.',
                  itemName: 'sector',
                  valueLabel: 'Valor BD',
                  nameLabel: 'Nombre visible',
                  service: widget.sectorService ?? SectorCatalogService(),
                  autoValueFromName: true,
                ),
                UserLogsPage(
                  service: widget.userAuditLogService ?? UserAuditLogService(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
