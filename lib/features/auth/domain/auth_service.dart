import 'auth_user.dart';

class ClientCodeSignInResult {
  const ClientCodeSignInResult({
    required this.requiresProfileCompletion,
  });

  final bool requiresProfileCompletion;
}

abstract class AuthService {
  Stream<AuthUser?> authStateChanges();

  AuthUser? get currentUser;

  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
    required bool rememberSession,
  });

  Future<ClientCodeSignInResult> signInWithClientCode({
    String? email,
    required String clientCode,
    String? documentNumber,
    String? contactNumber,
    required bool rememberSession,
  });

  Future<void> signOut();
}
