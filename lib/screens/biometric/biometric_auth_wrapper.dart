import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';

class BiometricAuthWrapper extends StatefulWidget {
  const BiometricAuthWrapper({
    super.key,
    required this.child,
    required this.isAuthenticated,
    required this.onAuthenticationSuccess,
    required this.onAuthenticationFailure,
  });

  final Widget child;
  final bool isAuthenticated;
  final VoidCallback onAuthenticationSuccess;
  final VoidCallback onAuthenticationFailure;

  @override
  State<BiometricAuthWrapper> createState() => _BiometricAuthWrapperState();
}

class _BiometricAuthWrapperState extends State<BiometricAuthWrapper> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _isAuthenticating = false;
  String _authStatus = 'Authenticating...';

  @override
  void initState() {
    super.initState();
    if (!widget.isAuthenticated) {
      _checkBiometricAvailability();
    }
  }

  Future<void> _checkBiometricAvailability() async {
    try {
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();

      if (canCheckBiometrics && isDeviceSupported) {
        await _authenticateWithBiometrics();
      } else {
        widget.onAuthenticationFailure();
      }
    } catch (_) {
      widget.onAuthenticationFailure();
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    if (_isAuthenticating) {
      return;
    }

    setState(() {
      _isAuthenticating = true;
      _authStatus = 'Please authenticate with your biometric credentials...';
    });

    try {
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
          useErrorDialogs: true,
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (!mounted) {
        return;
      }

      if (authenticated) {
        setState(() {
          _authStatus = 'Authentication successful!';
        });
        widget.onAuthenticationSuccess();
      } else {
        setState(() {
          _authStatus = 'Authentication failed. Please try again.';
        });
        widget.onAuthenticationFailure();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _authStatus = 'Authentication error: $error';
      });
      widget.onAuthenticationFailure();
    } finally {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isAuthenticated) {
      return widget.child;
    }

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.fingerprint,
                size: 100,
                color: Colors.blue,
              ),
              const SizedBox(height: 30),
              Text(
                _authStatus,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              if (!_isAuthenticating)
                ElevatedButton(
                  onPressed: _authenticateWithBiometrics,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 15,
                    ),
                  ),
                  child: const Text(
                    'Authenticate with Biometrics',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: widget.onAuthenticationFailure,
                child: const Text('Use Alternative Authentication'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
