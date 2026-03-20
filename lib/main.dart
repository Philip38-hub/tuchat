import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tuchat/config/supabase_config.dart';
import 'package:tuchat/firebase_options.dart';
import 'package:tuchat/providers/auth_provider.dart';
import 'package:tuchat/screens/auth/auth_flow_screen.dart';
import 'package:tuchat/screens/biometric/biometric_auth_wrapper.dart';
import 'package:tuchat/screens/home_screen.dart';
import 'package:tuchat/screens/profile/profile_setup_screen.dart';
import 'package:tuchat/services/auth_service.dart';
import 'package:tuchat/services/chat_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
  }

  runApp(
    MultiProvider(
      providers: [
        Provider(create: (_) => AuthService()),
        Provider(create: (_) => ChatService()),
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
          if (authProvider.isInitializing) {
            return const _SplashScreen();
          }

          if (!authProvider.isUserSignedIn) {
            return const AuthFlowScreen();
          }

          final nextScreen = authProvider.needsProfileSetup
              ? const ProfileSetupScreen()
              : const HomeScreen();

          return BiometricAuthWrapper(
            isAuthenticated: authProvider.isBiometricAuthenticated,
            onAuthenticationSuccess: authProvider.markBiometricAuthenticated,
            onAuthenticationFailure: authProvider.resetBiometricAuthentication,
            child: nextScreen,
          );
        },
      ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
