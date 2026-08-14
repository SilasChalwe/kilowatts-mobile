import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../auth/data/access_control_service.dart';
import '../../admin/screens/installer_portal_screen.dart';
import 'main_shell.dart';

/// The authenticated entry point keeps the two products separate:
/// installer/administrator work is web-only, while a homeowner always lands
/// in the simple mobile shell. Mobile no longer routes a normal user through
/// hardware discovery, GPIO, INA219 or safety-policy setup.
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
        if (kIsWeb) {
          return access.canManageHardware
              ? const InstallerPortalScreen()
              : const _InstallerAccessRequiredScreen();
        }

        // A Firebase account without an installation role is not a valid
        // homeowner account. Do not let a self-registered, unassigned user
        // reach broker configuration or household controls.
        return access.role == KilowattsRole.unassigned
            ? const _HomeownerAccessRequiredScreen()
            : const MainShell();
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
                    'This web console can configure physical relays, the Central battery sensor and safety limits. An administrator must assign your Firebase account the installer role before access is granted.',
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
