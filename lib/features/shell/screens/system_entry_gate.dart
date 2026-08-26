import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../admin/screens/installer_role_shell.dart';
import '../../auth/data/access_control_service.dart';
import 'main_shell.dart';

/// Authenticated role gate. A homeowner gets the normal control application.
/// An installer gets a superset experience on every platform: the complete
/// homeowner controls plus commissioning, Central operations and user access.
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
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final access = snapshot.data!;
        if (access.role == KilowattsRole.installer) {
          return const InstallerRoleShell();
        }

        if (access.role == KilowattsRole.homeowner) {
          return const MainShell();
        }

        return kIsWeb
            ? const _InstallerAccessRequiredScreen()
            : const _HomeownerAccessRequiredScreen();
      },
    );
  }
}

class _InstallerAccessRequiredScreen extends StatelessWidget {
  const _InstallerAccessRequiredScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.admin_panel_settings_outlined, size: 56),
                  const SizedBox(height: 20),
                  const Text(
                    'Installer access required',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'This web console can configure physical relays, the Central battery sensor and safety limits. An administrator must assign your account the installer role before access is granted.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () => AppStateScope.of(context).signOut(),
                    child: const Text('Sign out'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeownerAccessRequiredScreen extends StatelessWidget {
  const _HomeownerAccessRequiredScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.home_outlined, size: 56),
                  const SizedBox(height: 20),
                  const Text(
                    'System access required',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Your account has not yet been assigned to a Kilowatts installation. Ask the installer or administrator to assign the homeowner role and installation before connecting this phone.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () => AppStateScope.of(context).signOut(),
                    child: const Text('Sign out'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
