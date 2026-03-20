import 'dart:convert';
import 'dart:math' show Random;
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';
import 'package:tuchat/models/user.dart';

import 'base_service.dart';

class AuthService extends BaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final LocalAuthentication _localAuth = LocalAuthentication();

  AppUser? _cachedUser;

  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _biometricUserIdKey = 'biometric_user_id';
  static const String _biometricAuthTimeKey = 'biometric_auth_time';

  Future<AppUser?> signUp(
    String email,
    String password,
    String? displayName,
  ) async {
    try {
      log('Signing up user with email: $email');

      if (!isValidEmail(email)) {
        throw 'Please enter a valid email address.';
      }

      if (!isValidPassword(password)) {
        throw 'Password must be at least 6 characters long and contain at least one letter and one number.';
      }

      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final firebaseUser = userCredential.user;
      if (firebaseUser == null) {
        return null;
      }

      if (displayName != null && displayName.trim().isNotEmpty) {
        await firebaseUser.updateDisplayName(displayName.trim());
        await firebaseUser.reload();
      }

      final refreshedUser = _auth.currentUser ?? firebaseUser;
      final user = AppUser(
        uid: refreshedUser.uid,
        username: displayName?.trim() ?? '',
        email: refreshedUser.email ?? email,
        profilePicUrl: refreshedUser.photoURL ?? '',
        publicKey: _generatePublicKey(),
        createdAt: DateTime.now(),
        lastSeen: DateTime.now(),
      );

      await _createOrUpdateUserProfile(user: user, isNewUser: true);
      _cachedUser = user;

      log('User signed up successfully: ${user.uid}');
      return user;
    } catch (e) {
      final errorMessage = handleException(e);
      logError('Sign up failed: $errorMessage');
      throw errorMessage;
    }
  }

  Future<AppUser?> signIn(String email, String password) async {
    try {
      log('Signing in user with email: $email');

      if (!isValidEmail(email)) {
        throw 'Please enter a valid email address.';
      }

      if (password.isEmpty) {
        throw 'Please enter your password.';
      }

      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final firebaseUser = userCredential.user;
      if (firebaseUser == null) {
        return null;
      }

      final firestoreProfile = await _getUserProfile(firebaseUser.uid);
      final fallbackUser = AppUser.fromFirebaseAuth({
        'uid': firebaseUser.uid,
        'email': firebaseUser.email,
        'displayName': firebaseUser.displayName,
        'photoUrl': firebaseUser.photoURL,
      });

      final user =
          firestoreProfile ??
          fallbackUser.copyWith(publicKey: _generatePublicKey());
      await _createOrUpdateUserProfile(
        user: user.copyWith(lastSeen: DateTime.now()),
      );
      _cachedUser = await loadCurrentUserProfile();

      log('User signed in successfully: ${firebaseUser.uid}');
      return _cachedUser;
    } catch (e) {
      final errorMessage = handleException(e);
      logError('Sign in failed: $errorMessage');
      throw errorMessage;
    }
  }

  Future<void> signOut() async {
    try {
      log('Signing out user');
      await _auth.signOut();
      await _secureStorage.deleteAll();
      _cachedUser = null;
      log('User signed out successfully');
    } catch (e) {
      logError('Sign out failed: $e');
      throw handleException(e);
    }
  }

  bool isUserSignedIn() {
    return _auth.currentUser != null;
  }

  AppUser? getCurrentUser() {
    final firebaseUser = _auth.currentUser;
    if (_cachedUser != null) {
      return _cachedUser;
    }

    if (firebaseUser == null) {
      return null;
    }

    return AppUser.fromFirebaseAuth({
      'uid': firebaseUser.uid,
      'email': firebaseUser.email,
      'displayName': firebaseUser.displayName,
      'photoUrl': firebaseUser.photoURL,
    });
  }

  Future<AppUser?> loadCurrentUserProfile() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) {
      _cachedUser = null;
      return null;
    }

    final firestoreProfile = await _getUserProfile(firebaseUser.uid);
    _cachedUser =
        firestoreProfile ??
        AppUser.fromFirebaseAuth({
          'uid': firebaseUser.uid,
          'email': firebaseUser.email,
          'displayName': firebaseUser.displayName,
          'photoUrl': firebaseUser.photoURL,
        });
    return _cachedUser;
  }

  Future<bool> isUsernameAvailable(
    String username, {
    String? excludingUid,
  }) async {
    final normalized = username.trim().toLowerCase();
    if (normalized.isEmpty) {
      return false;
    }

    final query = await _firestore
        .collection('users')
        .where('usernameLowercase', isEqualTo: normalized)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      return true;
    }

    return query.docs.first.id == excludingUid;
  }

  Future<AppUser> completeProfile({
    required String username,
    Uint8List? profileImageBytes,
    String? profileImageName,
  }) async {
    try {
      final firebaseUser = _auth.currentUser;
      if (firebaseUser == null) {
        throw 'No user is currently signed in.';
      }

      final trimmedUsername = username.trim();
      if (!isValidUsername(trimmedUsername)) {
        throw 'Username must be 3-20 characters and use only letters, numbers, dots, or underscores.';
      }

      final isAvailable = await isUsernameAvailable(
        trimmedUsername,
        excludingUid: firebaseUser.uid,
      );
      if (!isAvailable) {
        throw 'That username is already taken.';
      }

      final existingUser = await _getUserProfile(firebaseUser.uid);
      final profilePicUrl = profileImageBytes != null
          ? _encodeProfilePicture(
              bytes: profileImageBytes,
              fileName: profileImageName,
            )
          : existingUser?.profilePicUrl ?? firebaseUser.photoURL ?? '';

      final updatedUser = AppUser(
        uid: firebaseUser.uid,
        username: trimmedUsername,
        email: firebaseUser.email ?? existingUser?.email ?? '',
        profilePicUrl: profilePicUrl,
        publicKey: existingUser?.publicKey.isNotEmpty == true
            ? existingUser!.publicKey
            : _generatePublicKey(),
        createdAt: existingUser?.createdAt ?? DateTime.now(),
        lastSeen: DateTime.now(),
      );

      await _createOrUpdateUserProfile(user: updatedUser);
      await firebaseUser.updateDisplayName(trimmedUsername);
      if (profilePicUrl.isNotEmpty) {
        await firebaseUser.updatePhotoURL(profilePicUrl);
      }
      await firebaseUser.reload();

      _cachedUser = updatedUser;
      return updatedUser;
    } catch (e) {
      final errorMessage = handleException(e);
      logError('Profile completion failed: $errorMessage');
      throw errorMessage;
    }
  }

  Future<void> _createOrUpdateUserProfile({
    required AppUser user,
    bool isNewUser = false,
  }) async {
    final userRef = _firestore.collection('users').doc(user.uid);
    final existingSnapshot = await userRef.get();
    final existingData = existingSnapshot.data();
    final now = DateTime.now();

    await userRef.set({
      'uid': user.uid,
      'username': user.username,
      'usernameLowercase': user.username.toLowerCase(),
      'email': user.email,
      'profilePicUrl': user.profilePicUrl,
      'publicKey': user.publicKey,
      'createdAt':
          existingData?['createdAt'] ?? Timestamp.fromDate(user.createdAt),
      'lastSeen': Timestamp.fromDate(user.lastSeen ?? now),
    }, SetOptions(merge: true));

    if (isNewUser) {
      log('Created Firestore profile for user: ${user.uid}');
    } else {
      log('Updated Firestore profile for user: ${user.uid}');
    }
  }

  Future<AppUser?> _getUserProfile(String uid) async {
    final snapshot = await _firestore.collection('users').doc(uid).get();
    if (!snapshot.exists) {
      return null;
    }

    final data = snapshot.data();
    if (data == null) {
      return null;
    }

    return AppUser.fromMap(data, uid);
  }

  String _encodeProfilePicture({required Uint8List bytes, String? fileName}) {
    const maxInlineImageBytes = 350 * 1024;
    if (bytes.length > maxInlineImageBytes) {
      throw 'Selected image is too large. Please choose a smaller photo.';
    }

    final extension = _extractFileExtension(fileName);
    final mimeType = _contentTypeForExtension(extension);
    final encoded = base64Encode(bytes);
    return 'data:$mimeType;base64,$encoded';
  }

  String _extractFileExtension(String? fileName) {
    if (fileName == null || !fileName.contains('.')) {
      return 'jpg';
    }

    final extension = fileName.split('.').last.toLowerCase();
    if (extension == 'png' || extension == 'webp' || extension == 'gif') {
      return extension;
    }
    return 'jpg';
  }

  String _contentTypeForExtension(String extension) {
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  String _generatePublicKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  Future<void> enableBiometricAuth() async {
    try {
      final user = getCurrentUser();
      if (user == null) {
        throw 'No user is currently signed in.';
      }

      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();

      if (!canCheckBiometrics || !isDeviceSupported) {
        throw 'Biometric authentication is not available on this device.';
      }

      await _secureStorage.write(key: _biometricEnabledKey, value: 'true');
      await _secureStorage.write(key: _biometricUserIdKey, value: user.uid);

      log('Biometric authentication enabled for user: ${user.uid}');
    } catch (e) {
      logError('Failed to enable biometric authentication: $e');
      throw handleException(e);
    }
  }

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

  Future<bool> isBiometricAuthEnabled() async {
    try {
      final isEnabled = await _secureStorage.read(key: _biometricEnabledKey);
      final userId = await _secureStorage.read(key: _biometricUserIdKey);
      final currentUser = getCurrentUser();

      return isEnabled == 'true' && userId == currentUser?.uid;
    } catch (e) {
      logError('Failed to check biometric authentication status: $e');
      return false;
    }
  }

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
            goToSettingsDescription:
                'Please set up your biometric credentials in your device settings.',
            goToSettingsButton: 'Settings',
          ),
          const IOSAuthMessages(
            cancelButton: 'Cancel',
            goToSettingsDescription:
                'Please set up your biometric credentials in your device settings.',
            goToSettingsButton: 'Settings',
          ),
        ],
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );

      if (authenticated) {
        await _secureStorage.write(
          key: _biometricAuthTimeKey,
          value: DateTime.now().millisecondsSinceEpoch.toString(),
        );
      }

      return authenticated;
    } catch (e) {
      logError('Biometric authentication failed: $e');
      throw handleException(e);
    }
  }

  Future<bool> needsReauthentication() async {
    try {
      final authTimeString = await _secureStorage.read(
        key: _biometricAuthTimeKey,
      );
      if (authTimeString == null) {
        return true;
      }

      final authTime = DateTime.fromMillisecondsSinceEpoch(
        int.parse(authTimeString),
      );
      final currentTime = DateTime.now();
      const sessionTimeout = Duration(minutes: 15);

      return currentTime.difference(authTime) > sessionTimeout;
    } catch (e) {
      logError('Failed to check reauthentication requirement: $e');
      return true;
    }
  }
}
