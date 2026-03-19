import 'package:flutter/material.dart';
import 'package:tuchat/screens/auth/sign_in_screen.dart';
import 'package:tuchat/screens/auth/sign_up_screen.dart';

class AuthFlowScreen extends StatefulWidget {
  const AuthFlowScreen({super.key});

  @override
  State<AuthFlowScreen> createState() => _AuthFlowScreenState();
}

class _AuthFlowScreenState extends State<AuthFlowScreen> {
  bool _showSignUp = false;

  void _toggleMode() {
    setState(() {
      _showSignUp = !_showSignUp;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: _showSignUp
          ? SignUpScreen(
              key: const ValueKey('sign-up-screen'),
              onSwitchToSignIn: _toggleMode,
            )
          : SignInScreen(
              key: const ValueKey('sign-in-screen'),
              onSwitchToSignUp: _toggleMode,
            ),
    );
  }
}
