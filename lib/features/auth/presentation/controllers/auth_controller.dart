import 'package:flutter/foundation.dart';

import '../../data/local_auth_service.dart';

class AuthController extends ChangeNotifier {
  AuthController({LocalAuthService? authService})
      : _authService = authService ?? LocalAuthService();

  final LocalAuthService _authService;

  bool _isLoading = false;
  bool _isAuthenticated = false;
  bool _rememberSession = true;
  String? _errorMessage;
  String? _currentUserName;

  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;
  bool get rememberSession => _rememberSession;
  String? get errorMessage => _errorMessage;
  String get currentUserName => _currentUserName ?? 'Usuario';

  void setRememberSession(bool value) {
    if (_rememberSession == value) {
      return;
    }

    _rememberSession = value;
    notifyListeners();
  }

  Future<bool> login({
    required String identifier,
    required String password,
  }) async {
    _setLoading(true);
    _errorMessage = null;

    final result = await _authService.login(
      identifier: identifier,
      password: password,
    );

    _isLoading = false;
    _isAuthenticated = result.isSuccess;
    _errorMessage = result.isSuccess ? null : result.message;
    _currentUserName = result.userName;
    notifyListeners();

    return result.isSuccess;
  }

  void logout() {
    _isAuthenticated = false;
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    if (_errorMessage == null) {
      return;
    }

    _errorMessage = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
