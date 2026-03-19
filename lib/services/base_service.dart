import 'package:flutter/foundation.dart';

/// Base service class that provides common functionality for all services
/// including error handling, logging, and common Firebase operations.
abstract class BaseService {
  /// Logs debug information
  void log(String message) {
    if (kDebugMode) {
      debugPrint('[${DateTime.now()}] [$runtimeType] $message');
    }
  }

  /// Logs error information
  void logError(String message, [StackTrace? stackTrace]) {
    debugPrint('[${DateTime.now()}] [ERROR] [$runtimeType] $message');
    if (stackTrace != null && kDebugMode) {
      debugPrint(stackTrace.toString());
    }
  }

  /// Handles errors and returns a user-friendly message
  String handleException(Object error) {
    logError('Exception occurred: $error');

    if (error is String) {
      return error;
    }

    // Handle Firebase Auth exceptions
    if (error.toString().contains('user-not-found')) {
      return 'No user found with this email address.';
    } else if (error.toString().contains('wrong-password')) {
      return 'Incorrect password. Please try again.';
    } else if (error.toString().contains('email-already-in-use')) {
      return 'An account with this email already exists.';
    } else if (error.toString().contains('invalid-email')) {
      return 'The email address is not valid.';
    } else if (error.toString().contains('weak-password')) {
      return 'The password is too weak. Please use a stronger password.';
    } else if (error.toString().contains('network-request-failed')) {
      return 'Network error. Please check your internet connection.';
    } else if (error.toString().contains('too-many-requests')) {
      return 'Too many requests. Please try again later.';
    } else if (error.toString().contains('CONFIGURATION_NOT_FOUND')) {
      return 'Firebase Auth Android configuration is incomplete. Add your Android app SHA fingerprints in Firebase Console and download an updated google-services.json.';
    }

    return 'An unexpected error occurred. Please try again.';
  }

  /// Validates email format
  bool isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }

  /// Validates password strength
  bool isValidPassword(String password) {
    // At least 6 characters, one letter and one number
    final passwordRegex = RegExp(
      r'^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d@$!%*#?&]{6,}$',
    );
    return passwordRegex.hasMatch(password);
  }

  /// Validates display name
  bool isValidDisplayName(String name) {
    return name.isNotEmpty && name.length >= 2 && name.length <= 50;
  }

  /// Validates usernames used in the user directory
  bool isValidUsername(String username) {
    final usernameRegex = RegExp(r'^[a-zA-Z0-9._]{3,20}$');
    return usernameRegex.hasMatch(username);
  }
}
