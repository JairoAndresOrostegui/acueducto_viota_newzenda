import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../domain/auth_exception.dart';
import '../domain/auth_service.dart';
import '../domain/auth_user.dart';

class FirebaseAuthService implements AuthService {
  FirebaseAuthService({FirebaseAuth? firebaseAuth})
      : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseAuth _firebaseAuth;

  @override
  AuthUser? get currentUser => _mapUser(_firebaseAuth.currentUser);

  @override
  Stream<AuthUser?> authStateChanges() {
    return _firebaseAuth.authStateChanges().map(_mapUser);
  }

  @override
  Future<void> signIn({
    required String email,
    required String password,
    required bool rememberSession,
  }) async {
    try {
      if (kIsWeb) {
        await _firebaseAuth.setPersistence(
          rememberSession
              ? Persistence.LOCAL
              : Persistence.SESSION,
        );
      }

      await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw AuthException(_mapError(error));
    } catch (_) {
      throw const AuthException(
        'No fue posible iniciar sesion en este momento. Intenta de nuevo.',
      );
    }
  }

  @override
  Future<void> signOut() {
    return _firebaseAuth.signOut();
  }

  AuthUser? _mapUser(User? user) {
    if (user == null || user.email == null) {
      return null;
    }

    return AuthUser(
      uid: user.uid,
      email: user.email!,
      displayName: user.displayName,
    );
  }

  String _mapError(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'El correo no tiene un formato valido.';
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Credenciales incorrectas. Verifica el correo y la clave.';
      case 'user-disabled':
        return 'Esta cuenta fue deshabilitada.';
      case 'too-many-requests':
        return 'Demasiados intentos. Espera un momento antes de reintentar.';
      case 'network-request-failed':
        return 'No hay conexion con Firebase. Revisa la red e intenta de nuevo.';
      case 'operation-not-allowed':
        return 'El proveedor de acceso no esta habilitado en Firebase Authentication.';
      default:
        return 'No fue posible iniciar sesion. Codigo: ${error.code}.';
    }
  }
}
