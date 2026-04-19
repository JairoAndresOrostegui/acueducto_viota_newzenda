import 'package:flutter/material.dart';

import '../features/auth/data/firebase_auth_service.dart';
import '../features/auth/presentation/controllers/auth_controller.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/catalogs/data/catalog_firestore_service.dart';
import '../features/home/presentation/pages/home_page.dart';
import '../features/users/data/user_admin_functions_service.dart';
import '../features/users/data/user_audit_log_service.dart';
import '../features/users/data/user_firestore_service.dart';
import '../theme/app_theme.dart';

class AcueductoViotaApp extends StatefulWidget {
  const AcueductoViotaApp({
    super.key,
    this.controller,
    this.userService,
    this.userAdminFunctionsService,
    this.documentTypeService,
    this.roleService,
    this.sectorService,
    this.userAuditLogService,
  });

  final AuthController? controller;
  final UserFirestoreService? userService;
  final UserAdminFunctionsService? userAdminFunctionsService;
  final DocumentTypeCatalogService? documentTypeService;
  final RoleCatalogService? roleService;
  final SectorCatalogService? sectorService;
  final UserAuditLogService? userAuditLogService;

  @override
  State<AcueductoViotaApp> createState() => _AcueductoViotaAppState();
}

class _AcueductoViotaAppState extends State<AcueductoViotaApp> {
  late final AuthController _authController =
      widget.controller ?? AuthController(authService: FirebaseAuthService());
  late final bool _ownsController = widget.controller == null;

  @override
  void dispose() {
    if (_ownsController) {
      _authController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _authController,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Acueducto Viota',
          theme: AppTheme.lightTheme,
          home: !_authController.isReady
              ? const _AppLoadingView()
              : _authController.isAuthenticated
              ? HomePage(
                  currentUserUid: _authController.currentUserUid ?? '',
                  userName: _authController.currentUserName,
                  onLogout: _authController.logout,
                  userService: widget.userService,
                  userAdminFunctionsService: widget.userAdminFunctionsService,
                  documentTypeService: widget.documentTypeService,
                  roleService: widget.roleService,
                  sectorService: widget.sectorService,
                  userAuditLogService: widget.userAuditLogService,
                )
              : LoginPage(controller: _authController),
        );
      },
    );
  }
}

class _AppLoadingView extends StatelessWidget {
  const _AppLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
