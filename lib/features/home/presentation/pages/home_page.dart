import 'package:flutter/material.dart';

import '../../../../core/presentation/text_formatters.dart';
import '../../../admin/presentation/pages/admin_console_page.dart';
import '../../../catalogs/data/catalog_firestore_service.dart';
import '../../../users/data/user_firestore_service.dart';
import '../../../users/data/user_admin_functions_service.dart';
import '../../../users/data/user_audit_log_service.dart';
import '../../../users/domain/app_user.dart';
import '../../../../theme/app_colors.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.currentUserUid,
    required this.userName,
    required this.onLogout,
    this.userService,
    this.userAdminFunctionsService,
    this.documentTypeService,
    this.roleService,
    this.sectorService,
    this.userAuditLogService,
  });

  final String currentUserUid;
  final String userName;
  final Future<void> Function() onLogout;
  final UserFirestoreService? userService;
  final UserAdminFunctionsService? userAdminFunctionsService;
  final DocumentTypeCatalogService? documentTypeService;
  final RoleCatalogService? roleService;
  final SectorCatalogService? sectorService;
  final UserAuditLogService? userAuditLogService;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel principal'),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await onLogout();
            },
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Salir'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: FutureBuilder<AppUser?>(
        future: (userService ?? UserFirestoreService()).getUser(currentUserUid),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            return _ProfileMissingView(
              userName: userName,
              currentUserUid: currentUserUid,
            );
          }

          final currentUser = snapshot.data!;

          if (currentUser.rol != 'administrador' ||
              currentUser.estado != 'activo') {
            return _NoAccessView(
              userName: userName,
              role: currentUser.rol,
              estado: currentUser.estado,
            );
          }

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: AdminConsolePage(
                  currentUser: currentUser,
                  userService: userService,
                  userAdminFunctionsService: userAdminFunctionsService,
                  documentTypeService: documentTypeService,
                  roleService: roleService,
                  sectorService: sectorService,
                  userAuditLogService: userAuditLogService,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProfileMissingView extends StatelessWidget {
  const _ProfileMissingView({
    required this.userName,
    required this.currentUserUid,
  });

  final String userName;
  final String currentUserUid;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFFE0ECE8)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bienvenido, ${toDisplayUserName(userName)}',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 10),
                Text(
                  'Tu usuario existe en Firebase Authentication, pero aún no tiene perfil en Firestore dentro de la colección usuarios.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 18),
                Text('UID actual: $currentUserUid'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NoAccessView extends StatelessWidget {
  const _NoAccessView({
    required this.userName,
    required this.role,
    required this.estado,
  });

  final String userName;
  final String role;
  final String estado;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFE0ECE8)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Acceso restringido para ${toDisplayUserName(userName)}',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 10),
            Text(
              'Este módulo solo está disponible para administradores activos. Perfil actual: $role / $estado.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
