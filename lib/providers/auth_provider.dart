import 'package:flutter/foundation.dart';
import 'package:tuchat/models/user.dart';
import 'package:tuchat/services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._authService);

  final AuthService _authService;

  bool _isBusy = false;
  bool _isBiometricAuthenticated = false;
  String? _errorMessage;

  bool get isBusy => _isBusy;
  bool get isBiometricAuthenticated => _isBiometricAuthenticated;
  String? get errorMessage => _errorMessage;
  bool get isUserSignedIn => _authService.isUserSignedIn();
  AppUser? get currentUser => _authService.getCurrentUser();

  Future<AppUser?> signUp(
    String email,
    String password,
    String? displayName,
  ) async {
    return _runWithState(() async {
      final user = await _authService.signUp(email, password, displayName);
      _isBiometricAuthenticated = false;
      return user;
    });
  }

  Future<AppUser?> signIn(String email, String password) async {
    return _runWithState(() async {
      final user = await _authService.signIn(email, password);
      _isBiometricAuthenticated = false;
      return user;
    });
  }

  Future<void> signOut() async {
    await _runWithState(() async {
      await _authService.signOut();
      _isBiometricAuthenticated = false;
      return null;
    });
  }

  Future<void> enableBiometricAuth() async {
    await _runWithState(() async {
      await _authService.enableBiometricAuth();
      return null;
    });
  }

  Future<void> disableBiometricAuth() async {
    await _runWithState(() async {
      await _authService.disableBiometricAuth();
      _isBiometricAuthenticated = false;
      return null;
    });
  }

  Future<bool> authenticateWithBiometrics() async {
    return _runWithState(() async {
      final authenticated = await _authService.authenticateWithBiometrics();
      _isBiometricAuthenticated = authenticated;
      return authenticated;
    }).then((value) => value ?? false);
  }

  Future<bool> isBiometricAuthEnabled() {
    return _authService.isBiometricAuthEnabled();
  }

  Future<bool> needsReauthentication() {
    return _authService.needsReauthentication();
  }

  void markBiometricAuthenticated() {
    if (_isBiometricAuthenticated) {
      return;
    }

    _isBiometricAuthenticated = true;
    notifyListeners();
  }

  void resetBiometricAuthentication() {
    if (!_isBiometricAuthenticated && _errorMessage == null) {
      return;
    }

    _isBiometricAuthenticated = false;
    _errorMessage = null;
    notifyListeners();
  }

  Future<T?> _runWithState<T>(Future<T?> Function() action) async {
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      return await action();
    } catch (error) {
      _errorMessage = error.toString();
      rethrow;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  void clearError() {
    if (_errorMessage == null) {
      return;
    }

    _errorMessage = null;
    notifyListeners();
  }
}
