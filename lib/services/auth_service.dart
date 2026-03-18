import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';
import 'package:tuchat/models/user.dart';
import 'base_service.dart';

class AuthService extends BaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final LocalAuthentication _localAuth = LocalAuthentication();

  // Keys for secure storage
  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _biometricUserIdKey = 'biometric_user_id';
  static const String _biometricAuthTimeKey = 'biometric_auth_time';

  /// Signs up a new user with email and password
  Future<AppUser?> signUp(String email, String password, String? displayName) async {
    try {
      log('Signing up user with email: $email');
      
      if (!isValidEmail(email)) {
        throw 'Please enter a valid email address.';
      }
      
      if (!isValidPassword(password)) {
        throw 'Password must be at least 6 characters long and contain at least one letter and one number.';
      }

      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final firebaseUser = userCredential.user;
      if (firebaseUser != null) {
        // Update display name if provided
        if (displayName != null && isValidDisplayName(displayName)) {
          await firebaseUser.updateDisplayName(displayName);
        }

        // Store user data in Firestore would go here
        // For now, we'll create a basic AppUser object
        
        final user = AppUser.fromFirebaseAuth({
          'uid': firebaseUser.uid,
          'email': firebaseUser.email,
          'displayName': firebaseUser.displayName,
          'photoUrl': firebaseUser.photoURL,
        });

        log('User signed up successfully: ${user.id}');
        return user;
      }
    } catch (e) {
      final errorMessage = handleException(e);
      logError('Sign up failed: $errorMessage');
      throw errorMessage;
    }
    return null;
  }

  /// Signs in an existing user with email and password
  Future<AppUser?> signIn(String email, String password) async {
    try {
      log('Signing in user with email: $email');
      
      if (!isValidEmail(email)) {
        throw 'Please enter a valid email address.';
      }
      
      if (password.isEmpty) {
        throw 'Please enter your password.';
      }

      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final firebaseUser = userCredential.user;
      if (firebaseUser != null) {
        final user = AppUser.fromFirebaseAuth({
          'uid': firebaseUser.uid,
          'email': firebaseUser.email,
          'displayName': firebaseUser.displayName,
          'photoUrl': firebaseUser.photoURL,
        });

        log('User signed in successfully: ${user.id}');
        return user;
      }
    } catch (e) {
      final errorMessage = handleException(e);
      logError('Sign in failed: $errorMessage');
      throw errorMessage;
    }
    return null;
  }

  /// Signs out the current user
  Future<void> signOut() async {
    try {
      log('Signing out user');
      await _auth.signOut();
      await _secureStorage.deleteAll();
      log('User signed out successfully');
    } catch (e) {
      logError('Sign out failed: $e');
      throw handleException(e);
    }
  }

  /// Checks if the user is currently signed in
  bool isUserSignedIn() {
    return _auth.currentUser != null;
  }

  /// Gets the current user
  AppUser? getCurrentUser() {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser != null) {
      return AppUser.fromFirebaseAuth({
        'uid': firebaseUser.uid,
        'email': firebaseUser.email,
        'displayName': firebaseUser.displayName,
        'photoUrl': firebaseUser.photoURL,
      });
    }
    return null;
  }

  /// Enables biometric authentication for the current user
  Future<void> enableBiometricAuth() async {
    try {
      final user = getCurrentUser();
      if (user == null) {
        throw 'No user is currently signed in.';
      }

      // Check if biometric authentication is available
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();

      if (!canCheckBiometrics || !isDeviceSupported) {
        throw 'Biometric authentication is not available on this device.';
      }

      // Store that biometric auth is enabled for this user
      await _secureStorage.write(key: _biometricEnabledKey, value: 'true');
      await _secureStorage.write(key: _biometricUserIdKey, value: user.id);
      
      log('Biometric authentication enabled for user: ${user.id}');
    } catch (e) {
      logError('Failed to enable biometric authentication: $e');
      throw handleException(e);
    }
  }

  /// Disables biometric authentication for the current user
  Future<void> disableBiometricAuth() async {
    try {
      await _secureStorage.delete(key: _biometricEnabledKey);
      await _secureStorage.delete(key: _biometricUserIdKey);
      await _secureStorage.delete(key: _biometricAuthTimeKey);
      
      log('Biometric authentication disabled');
    } catch (e) {
      logError('Failed to disable biometric authentication: $e');
      throw handleException(e);
    }
  }

  /// Checks if biometric authentication is enabled for the current user
  Future<bool> isBiometricAuthEnabled() async {
    try {
      final isEnabled = await _secureStorage.read(key: _biometricEnabledKey);
      final userId = await _secureStorage.read(key: _biometricUserIdKey);
      final currentUser = getCurrentUser();
      
      return isEnabled == 'true' && userId == currentUser?.id;
    } catch (e) {
      logError('Failed to check biometric authentication status: $e');
      return false;
    }
  }

  /// Performs biometric authentication
  Future<bool> authenticateWithBiometrics() async {
    try {
      if (!await isBiometricAuthEnabled()) {
        throw 'Biometric authentication is not enabled.';
      }

      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();

      if (!canCheckBiometrics || !isDeviceSupported) {
        throw 'Biometric authentication is not available on this device.';
      }

      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate to access TuChat',
        authMessages: [
          const AndroidAuthMessages(
            signInTitle: 'Authenticate to access TuChat',
            cancelButton: 'Cancel',
            goToSettingsDescription: 'Please set up your biometric credentials in your device settings.',
            goToSettingsButton: 'Settings',
          ),
          const IOSAuthMessages(
            cancelButton: 'Cancel',
            goToSettingsDescription: 'Please set up your biometric credentials in your device settings.',
            goToSettingsButton: 'Settings',
          ),
        ],
        options: const AuthenticationOptions(
          useErrorDialogs: true,
          stickyAuth: true,
        ),
      );

      if (authenticated) {
        // Store the authentication time
        await _secureStorage.write(
          key: _biometricAuthTimeKey, 
          value: DateTime.now().toIso8601String()
        );
        log('Biometric authentication successful');
      }

      return authenticated;
    } catch (e) {
      logError('Biometric authentication failed: $e');
      throw handleException(e);
    }
  }

  /// Checks if the user needs to re-authenticate (e.g., after a certain time period)
  Future<bool> needsReauthentication() async {
    try {
      if (!await isBiometricAuthEnabled()) {
        return true;
      }

      final authTimeStr = await _secureStorage.read(key: _biometricAuthTimeKey);
      if (authTimeStr == null) {
        return true;
      }

      final authTime = DateTime.parse(authTimeStr);
      final timeSinceAuth = DateTime.now().difference(authTime);
      
      // Require re-authentication after 30 minutes
      return timeSinceAuth.inMinutes > 30;
    } catch (e) {
      logError('Failed to check reauthentication status: $e');
      return true;
    }
  }
}
