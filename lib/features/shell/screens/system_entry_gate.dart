import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../setup/screens/system_connection_screen.dart';
import 'main_shell.dart';

/// The hand-off point after Firebase authentication succeeds. A verified
/// user either still needs to walk through first-time system setup, or has
/// already finished it and goes straight to the dashboard.
class SystemEntryGate extends StatefulWidget {
  const SystemEntryGate({super.key});

  @override
  State<SystemEntryGate> createState() => _SystemEntryGateState();
}

class _SystemEntryGateState extends State<SystemEntryGate> {
  Future<bool>? _setupCompleteFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _setupCompleteFuture ??= AppStateScope.of(context).isSetupComplete();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _setupCompleteFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.data!) {
          return const MainShell();
        }

        return const SystemConnectionScreen();
      },
    );
  }
}
