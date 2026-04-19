class AuthUser {
  const AuthUser({
    required this.uid,
    required this.email,
    this.displayName,
  });

  final String uid;
  final String email;
  final String? displayName;

  String get preferredName {
    final normalizedName = displayName?.trim();
    if (normalizedName != null && normalizedName.isNotEmpty) {
      return normalizedName;
    }

    return email;
  }

  String get firstLetter {
    final value = preferredName.trim();
    if (value.isEmpty) {
      return 'U';
    }
    return value.substring(0, 1).toUpperCase();
  }
}
