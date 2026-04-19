class AuthResult {
  const AuthResult({
    required this.isSuccess,
    required this.message,
    this.userName,
  });

  final bool isSuccess;
  final String message;
  final String? userName;
}
