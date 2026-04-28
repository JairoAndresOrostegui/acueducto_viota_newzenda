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

  Future<bool> loginWithEmailAndPassword({
    required String email,
    required String password,
  }) {
    return _login(
      () => _authService.signInWithEmailAndPassword(
        email: email,
        password: password,
        rememberSession: _rememberSession,
      ),
    );
  }

  Future<ClientCodeLoginResult> loginWithClientCode({
    String? email,
    required String clientCode,
    String? documentNumber,
    String? contactNumber,
  }) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final result = await _authService.signInWithClientCode(
        email: email,
        clientCode: clientCode,
        documentNumber: documentNumber,
        contactNumber: contactNumber,
        rememberSession: _rememberSession,
      );
      if (result.requiresProfileCompletion) {
        return const ClientCodeLoginResult(requiresProfileCompletion: true);
      }
      _currentUser = _authService.currentUser;
      _isAuthenticated = _currentUser != null;
      return ClientCodeLoginResult(success: _isAuthenticated);
    } on AuthException catch (error) {
      _errorMessage = error.message;
      _isAuthenticated = false;
      return const ClientCodeLoginResult(success: false);
    } catch (_) {
      _errorMessage =
          'No fue posible iniciar sesión en este momento. Intenta de nuevo.';
      _isAuthenticated = false;
      return const ClientCodeLoginResult(success: false);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> _login(Future<void> Function() signIn) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      await signIn();
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

class ClientCodeLoginResult {
  const ClientCodeLoginResult({
    this.success = false,
    this.requiresProfileCompletion = false,
  });

  final bool success;
  final bool requiresProfileCompletion;
}
