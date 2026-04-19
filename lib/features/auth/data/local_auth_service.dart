import '../domain/auth_result.dart';

class LocalAuthService {
  static const String validIdentifier = 'admin@acueductoviota.com';
  static const String validPassword = 'Agua2026*';
  static const String displayName = 'Administrador del Acueducto';

  Future<AuthResult> login({
    required String identifier,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));

    final normalizedIdentifier = identifier.trim().toLowerCase();

    if (normalizedIdentifier == validIdentifier.toLowerCase() &&
        password == validPassword) {
      return const AuthResult(
        isSuccess: true,
        message: 'Acceso concedido.',
        userName: displayName,
      );
    }

    return const AuthResult(
      isSuccess: false,
      message: 'Credenciales incorrectas. Verifica el correo y la clave.',
    );
  }
}
