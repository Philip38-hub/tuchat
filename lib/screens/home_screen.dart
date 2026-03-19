import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tuchat/providers/auth_provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider?>();
    final user = authProvider?.currentUser;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('TuChat'),
        actions: [
          if (authProvider != null)
            IconButton(
              onPressed: authProvider.isBusy
                  ? null
                  : () async {
                      await context.read<AuthProvider>().signOut();
                    },
              icon: const Icon(Icons.logout),
              tooltip: 'Sign out',
            ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.chat,
              size: 100,
              color: Colors.blue,
            ),
            const SizedBox(height: 20),
            const Text(
              'Welcome to TuChat!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Your secure messaging app',
              style: TextStyle(fontSize: 16),
            ),
            if (user != null) ...[
              const SizedBox(height: 16),
              Text(
                user.displayName?.isNotEmpty == true
                    ? 'Signed in as ${user.displayName}'
                    : 'Signed in as ${user.email}',
              ),
            ],
          ],
        ),
      ),
    );
  }
}
