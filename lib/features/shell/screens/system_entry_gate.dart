import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../admin/screens/installer_role_shell.dart';
import '../../auth/data/access_control_service.dart';
import 'main_shell.dart';

/// Resolves the signed-in account to the one product shell it may access.
class SystemEntryGate extends StatefulWidget {
  const SystemEntryGate({super.key});

  @override
  State<SystemEntryGate> createState() => _SystemEntryGateState();
}

class _SystemEntryGateState extends State<SystemEntryGate> {
  Future<InstallationAccess>? _access;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _access ??= AppStateScope.of(context).resolveCurrentAccess();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<InstallationAccess>(
      future: _access,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: SafeArea(
              child: LoadingIndicator(message: 'Opening your workspace…'),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return _AccessState(
            title: 'Access could not be verified',
            message:
                'Check your network connection and try signing in again. Your system settings have not been changed.',
            icon: Icons.cloud_off_outlined,
          );
        }

        final access = snapshot.data!;
        if (access.role == KilowattsRole.installer) {
          return const InstallerRoleShell();
        }

        if (access.role == KilowattsRole.homeowner) {
          return const MainShell();
        }

        return const _AccessState(
          title: 'Installation access required',
          message:
              'This account has not yet been assigned a Kilowatts role and installation. Ask an installer or administrator to grant access.',
          icon: Icons.admin_panel_settings_outlined,
        );
      },
    );
  }
}

class _AccessState extends StatelessWidget {
  const _AccessState({
    required this.title,
    required this.message,
    required this.icon,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: EmptyState(
            icon: icon,
            title: title,
            message: message,
            action: OutlinedButton.icon(
              onPressed: () => AppStateScope.of(context).signOut(),
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text('Sign out'),
            ),
          ),
        ),
      ),
    );
  }
}
