import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'screens/auth/auth_flow_screen.dart';
import 'screens/biometric/biometric_auth_wrapper.dart';
import 'screens/home_screen.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    MultiProvider(
      providers: [
        Provider(create: (_) => AuthService()),
        ChangeNotifierProxyProvider<AuthService, AuthProvider>(
          create: (context) => AuthProvider(context.read<AuthService>()),
          update: (context, authService, previous) =>
              previous ?? AuthProvider(authService),
        ),
      ],
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
      home: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          if (!authProvider.isUserSignedIn) {
            return const AuthFlowScreen();
          }

          return BiometricAuthWrapper(
            isAuthenticated: authProvider.isBiometricAuthenticated,
            onAuthenticationSuccess: authProvider.markBiometricAuthenticated,
            onAuthenticationFailure:
                authProvider.resetBiometricAuthentication,
            child: const HomeScreen(),
          );
        },
      ),
    );
  }
}
