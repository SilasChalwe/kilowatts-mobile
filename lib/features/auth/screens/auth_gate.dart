import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../shell/screens/system_entry_gate.dart';
import 'email_verification_screen.dart';
import 'welcome_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);

    return StreamBuilder<User?>(
      stream: appState.userChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return const WelcomeScreen();
        }

        if (!user.emailVerified) {
          return EmailVerificationScreen(email: user.email ?? '');
        }

        return const SystemEntryGate();
      },
    );
  }
}
