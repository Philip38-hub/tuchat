import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'views/biometric/biometric_auth_wrapper.dart';
import 'services/auth_service.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthService(),
      child: const TuChatApp(),
    ),
  );
}

class TuChatApp extends StatelessWidget {
  const TuChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TuChat',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: BiometricAuthWrapper(
        isAuthenticated: false,
        onAuthenticationSuccess: () {
          // This will be handled by the main app logic
        },
        onAuthenticationFailure: () {
          // This will be handled by the main app logic
        },
        child: const HomeScreen(),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('TuChat'),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat,
              size: 100,
              color: Colors.blue,
            ),
            SizedBox(height: 20),
            Text(
              'Welcome to TuChat!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Your secure messaging app',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
