import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/auth_exception.dart';
import '../../domain/auth_service.dart';
import '../../domain/auth_user.dart';

class AuthController extends ChangeNotifier {
  AuthController({required AuthService authService}) : _authService = authService {
    _authSubscription = _authService.authStateChanges().listen(_handleAuthChange);
    _currentUser = _authService.currentUser;
    _isAuthenticated = _currentUser != null;
    _isReady = true;
  }

  final AuthService _authService;
  late final StreamSubscription<AuthUser?> _authSubscription;

  bool _isLoading = false;
  bool _isReady = false;
  bool _isAuthenticated = false;
  bool _rememberSession = true;
  String? _errorMessage;
  AuthUser? _currentUser;

  bool get isLoading => _isLoading;
  bool get isReady => _isReady;
  bool get isAuthenticated => _isAuthenticated;
  bool get rememberSession => _rememberSession;
  String? get errorMessage => _errorMessage;
  String get currentUserName => _currentUser?.preferredName ?? 'Usuario';
  String? get currentUserUid => _currentUser?.uid;
  String? get currentUserEmail => _currentUser?.email;

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

    try {
      await _authService.signIn(
        email: identifier,
        password: password,
        rememberSession: _rememberSession,
      );
      _currentUser = _authService.currentUser;
      _isAuthenticated = _currentUser != null;
      return _isAuthenticated;
    } on AuthException catch (error) {
      _errorMessage = error.message;
      _isAuthenticated = false;
      return false;
    } catch (_) {
      _errorMessage =
          'No fue posible iniciar sesión en este momento. Intenta de nuevo.';
      _isAuthenticated = false;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _errorMessage = null;
    await _authService.signOut();
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

  void _handleAuthChange(AuthUser? user) {
    _currentUser = user;
    _isAuthenticated = user != null;
    _isReady = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }
}
