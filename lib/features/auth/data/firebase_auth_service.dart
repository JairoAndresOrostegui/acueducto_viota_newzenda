import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../domain/auth_exception.dart';
import '../domain/auth_service.dart';
import '../domain/auth_user.dart';

class FirebaseAuthService implements AuthService {
  FirebaseAuthService({
    FirebaseAuth? firebaseAuth,
    FirebaseFunctions? functions,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseAuth _firebaseAuth;
  final FirebaseFunctions _functions;

  @override
  AuthUser? get currentUser => _mapUser(_firebaseAuth.currentUser);

  @override
  Stream<AuthUser?> authStateChanges() {
    return _firebaseAuth.authStateChanges().map(_mapUser);
  }

  @override
  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
    required bool rememberSession,
  }) async {
    try {
      await _setPersistence(rememberSession);
      await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw AuthException(_mapError(error));
    } catch (_) {
      throw const AuthException(
        'No fue posible iniciar sesión en este momento. Intenta de nuevo.',
      );
    }
  }

  @override
  Future<ClientCodeSignInResult> signInWithClientCode({
    String? email,
    required String clientCode,
    String? documentNumber,
    String? contactNumber,
    required bool rememberSession,
  }) async {
    try {
      await _setPersistence(rememberSession);
      final callable = _functions.httpsCallable('signInWithClientCode');
      final result = await callable.call<Map<String, dynamic>>({
        'correo': email?.trim().toLowerCase(),
        'codigoUsuario': clientCode.trim().toUpperCase(),
        'numeroDocumento': documentNumber?.trim(),
        'numeroContacto': contactNumber?.trim(),
      });
      final requiresProfileCompletion =
          result.data['requiresProfileCompletion'] == true;
      if (requiresProfileCompletion) {
        return const ClientCodeSignInResult(requiresProfileCompletion: true);
      }
      final token = result.data['token'] as String?;
      if (token == null || token.isEmpty) {
        throw const AuthException(
          'No fue posible iniciar sesión con este usuario.',
        );
      }
      await _firebaseAuth.signInWithCustomToken(token);
      return const ClientCodeSignInResult(requiresProfileCompletion: false);
    } on FirebaseFunctionsException catch (error) {
      throw AuthException(_mapFunctionsError(error));
    } on FirebaseAuthException catch (error) {
      throw AuthException(_mapError(error));
    } catch (_) {
      throw const AuthException(
        'No fue posible iniciar sesión en este momento. Intenta de nuevo.',
      );
    }
  }

  @override
  Future<void> signOut() {
    return _firebaseAuth.signOut();
  }

  Future<void> _setPersistence(bool rememberSession) async {
    if (!kIsWeb) {
      return;
    }
    await _firebaseAuth.setPersistence(
      rememberSession ? Persistence.LOCAL : Persistence.SESSION,
    );
  }

  AuthUser? _mapUser(User? user) {
    if (user == null) {
      return null;
    }

    return AuthUser(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName,
    );
  }

  String _mapError(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'El correo no tiene un formato válido.';
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Credenciales incorrectas. Verifica el correo y la clave.';
      case 'user-disabled':
        return 'Esta cuenta fue deshabilitada.';
      case 'too-many-requests':
        return 'Demasiados intentos. Espera un momento antes de reintentar.';
      case 'network-request-failed':
        return 'No hay conexión con Firebase. Revisa la red e intenta de nuevo.';
      case 'operation-not-allowed':
        return 'El proveedor de acceso no está habilitado en Firebase Authentication.';
      default:
        return 'No fue posible iniciar sesión. Código: ${error.code}.';
    }
  }

  String _mapFunctionsError(FirebaseFunctionsException error) {
    final message = error.message?.trim();
    if (message != null && message.isNotEmpty) {
      return message;
    }

    switch (error.code) {
      case 'not-found':
        return 'No existe un cliente activo con ese código de usuario.';
      case 'permission-denied':
        return 'El correo no coincide con el código de usuario.';
      case 'invalid-argument':
        return 'Ingresa los datos requeridos para iniciar sesión.';
      default:
        return 'No fue posible iniciar sesión. Código: ${error.code}.';
    }
  }
}
