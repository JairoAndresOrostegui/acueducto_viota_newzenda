import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontacueductonewzenda/app/app.dart';
import 'package:frontacueductonewzenda/features/auth/domain/auth_exception.dart';
import 'package:frontacueductonewzenda/features/auth/domain/auth_service.dart';
import 'package:frontacueductonewzenda/features/auth/domain/auth_user.dart';
import 'package:frontacueductonewzenda/features/auth/presentation/controllers/auth_controller.dart';
import 'package:frontacueductonewzenda/features/catalogs/data/catalog_firestore_service.dart';
import 'package:frontacueductonewzenda/features/catalogs/domain/catalog_item.dart';
import 'package:frontacueductonewzenda/features/users/data/user_admin_functions_service.dart';
import 'package:frontacueductonewzenda/features/users/data/user_audit_log_service.dart';
import 'package:frontacueductonewzenda/features/users/data/user_firestore_service.dart';
import 'package:frontacueductonewzenda/features/users/domain/app_user.dart';
import 'package:frontacueductonewzenda/features/users/domain/user_audit_log.dart';

void main() {
  testWidgets('shows validation errors before submitting login', (tester) async {
    await tester.pumpWidget(
      AcueductoViotaApp(
        controller: AuthController(authService: FakeAuthService()),
        userService: FakeUserFirestoreService(),
        userAdminFunctionsService: FakeUserAdminFunctionsService(),
        documentTypeService: FakeDocumentTypeCatalogService(),
        roleService: FakeRoleCatalogService(),
        sectorService: FakeSectorCatalogService(),
        userAuditLogService: FakeUserAuditLogService(),
      ),
    );

    await tester.tap(find.text('Ingresar'));
    await tester.pump();

    expect(find.text('Ingresa el correo de acceso.'), findsOneWidget);
    expect(find.text('Ingresa la clave.'), findsOneWidget);
  });

  testWidgets('allows login with a valid auth service user', (tester) async {
    await tester.pumpWidget(
      AcueductoViotaApp(
        controller: AuthController(authService: FakeAuthService()),
        userService: FakeUserFirestoreService(),
        userAdminFunctionsService: FakeUserAdminFunctionsService(),
        documentTypeService: FakeDocumentTypeCatalogService(),
        roleService: FakeRoleCatalogService(),
        sectorService: FakeSectorCatalogService(),
        userAuditLogService: FakeUserAuditLogService(),
      ),
    );

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'admin@acueducto.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'Segura2026*');

    await tester.tap(find.text('Ingresar'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Usuarios'), findsWidgets);
    expect(find.text('Nuevo usuario'), findsOneWidget);
  });
}

class FakeAuthService implements AuthService {
  final StreamController<AuthUser?> _controller =
      StreamController<AuthUser?>.broadcast();
  AuthUser? _currentUser;

  @override
  Stream<AuthUser?> authStateChanges() async* {
    yield _currentUser;
    yield* _controller.stream;
  }

  @override
  AuthUser? get currentUser => _currentUser;

  @override
  Future<void> signIn({
    required String email,
    required String password,
    required bool rememberSession,
  }) async {
    if (email == 'admin@acueducto.com' && password == 'Segura2026*') {
      _currentUser = const AuthUser(
        uid: 'test-user',
        email: 'admin@acueducto.com',
        displayName: 'Administrador',
      );
      _controller.add(_currentUser);
      return;
    }

    throw const AuthException('Credenciales invalidas');
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _controller.add(null);
  }
}

class FakeUserFirestoreService extends UserFirestoreService {
  AppUser _adminProfile(String uid) {
    return AppUser(
      uid: uid,
      nombre: 'Administrador',
      tipoDocumento: 'CC',
      numeroDocumento: '1095795008',
      numeroContacto: '3012176100',
      codigoUsuario: 'NA',
      numeroContador: 'NA',
      rol: 'administrador',
      sector: 'NA',
      correo: 'admin@acueducto.com',
      estado: 'activo',
      fechaCreacion: DateTime(2026, 4, 18),
    );
  }

  @override
  Future<AppUser?> getUser(String uid) async {
    return _adminProfile(uid);
  }

  @override
  Stream<List<AppUser>> watchUsers({int limit = 200}) async* {
    yield [_adminProfile('test-user')];
  }
}

class FakeUserAdminFunctionsService extends UserAdminFunctionsService {
  @override
  Future<String> createManagedUser({
    required AppUser user,
    required String password,
  }) async {
    return 'created-user';
  }

  @override
  Future<void> updateManagedUser({
    required AppUser user,
    String? password,
  }) async {}

  @override
  Future<void> deleteManagedUser(String uid) async {}
}

class FakeDocumentTypeCatalogService extends DocumentTypeCatalogService {
  @override
  Future<List<CatalogItem>> fetchActiveItems({int limit = 100}) async {
    return [
      CatalogItem(
        id: 'cc',
        valor: 'CC',
        nombre: 'Cedula de ciudadania',
        estado: 'activo',
        fechaCreacion: DateTime(2026, 4, 18),
      ),
    ];
  }

  @override
  Future<void> ensureDefaults(List<CatalogItem> defaults) async {}
}

class FakeRoleCatalogService extends RoleCatalogService {
  @override
  Future<List<CatalogItem>> fetchActiveItems({int limit = 100}) async {
    return [
      CatalogItem(
        id: 'administrador',
        valor: 'administrador',
        nombre: 'Administrador',
        estado: 'activo',
        fechaCreacion: DateTime(2026, 4, 18),
      ),
      CatalogItem(
        id: 'cliente',
        valor: 'cliente',
        nombre: 'Cliente',
        estado: 'activo',
        fechaCreacion: DateTime(2026, 4, 18),
      ),
    ];
  }

  @override
  Future<void> ensureDefaults(List<CatalogItem> defaults) async {}
}

class FakeSectorCatalogService extends SectorCatalogService {
  @override
  Future<List<CatalogItem>> fetchActiveItems({int limit = 100}) async {
    return [
      CatalogItem(
        id: 'quitasol',
        valor: 'Quitasol',
        nombre: 'Quitasol',
        estado: 'activo',
        fechaCreacion: DateTime(2026, 4, 18),
      ),
    ];
  }
}

class FakeUserAuditLogService extends UserAuditLogService {
  @override
  Stream<List<UserAuditLog>> watchLogs({
    String? query,
    int limit = 50,
  }) async* {
    yield const [];
  }
}
