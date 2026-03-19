import 'package:flutter/foundation.dart';
import 'package:tuchat/models/user.dart';
import 'package:tuchat/services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._authService) {
    _initialize();
  }

  final AuthService _authService;

  bool _isBusy = false;
  bool _isInitializing = true;
  bool _isBiometricAuthenticated = false;
  String? _errorMessage;
  AppUser? _currentUser;

  bool get isBusy => _isBusy;
  bool get isInitializing => _isInitializing;
  bool get isBiometricAuthenticated => _isBiometricAuthenticated;
  String? get errorMessage => _errorMessage;
  bool get isUserSignedIn => _authService.isUserSignedIn();
  AppUser? get currentUser => _currentUser;
  bool get needsProfileSetup =>
      isUserSignedIn && (_currentUser?.isProfileComplete != true);

  Future<void> _initialize() async {
    try {
      if (isUserSignedIn) {
        _currentUser = await _authService.loadCurrentUserProfile();
      }
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  Future<AppUser?> signUp(
    String email,
    String password,
    String? displayName,
  ) async {
    return _runWithState(() async {
      final user = await _authService.signUp(email, password, displayName);
      _currentUser = user;
      _isBiometricAuthenticated = false;
      return user;
    });
  }

  Future<AppUser?> signIn(String email, String password) async {
    return _runWithState(() async {
      final user = await _authService.signIn(email, password);
      _currentUser = user;
      _isBiometricAuthenticated = false;
      return user;
    });
  }

  Future<AppUser?> completeProfile({
    required String username,
    Uint8List? profileImageBytes,
    String? profileImageName,
  }) async {
    return _runWithState(() async {
      final user = await _authService.completeProfile(
        username: username,
        profileImageBytes: profileImageBytes,
        profileImageName: profileImageName,
      );
      _currentUser = user;
      return user;
    });
  }

  Future<void> signOut() async {
    await _runWithState(() async {
      await _authService.signOut();
      _currentUser = null;
      _isBiometricAuthenticated = false;
      return null;
    });
  }

  Future<void> refreshCurrentUser() async {
    await _runWithState(() async {
      _currentUser = await _authService.loadCurrentUserProfile();
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
      _isInitializing = false;
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
