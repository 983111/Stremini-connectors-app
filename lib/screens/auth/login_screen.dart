import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Welcome to Stremini'),
              const SizedBox(height: 12),
              if (auth.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(auth.error!, style: const TextStyle(color: Colors.red)),
                ),
              ElevatedButton(
                onPressed: auth.isLoading ? null : () => context.read<AuthProvider>().signIn(),
                child: Text(auth.isLoading ? 'Signing in...' : 'Sign in with Google'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
