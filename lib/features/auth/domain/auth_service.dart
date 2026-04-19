import 'auth_user.dart';

abstract class AuthService {
  Stream<AuthUser?> authStateChanges();

  AuthUser? get currentUser;

  Future<void> signIn({
    required String email,
    required String password,
    required bool rememberSession,
  });

  Future<void> signOut();
}
