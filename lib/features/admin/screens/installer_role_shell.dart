import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../shell/screens/main_shell.dart';
import 'installer_portal_screen.dart';
import 'installer_users_screen.dart';

/// Installer/admin experience is deliberately a superset of the homeowner
/// product. The first tab is the exact homeowner shell, so an installer can
/// monitor telemetry, control FIXED loads, change priority/schedules, inspect
/// topology/alerts, battery data and reports. Additional tabs expose physical
/// commissioning and account administration.
class InstallerRoleShell extends StatelessWidget {
  const InstallerRoleShell({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Kilowatts installer'),
          actions: [
            IconButton(
              tooltip: 'Sign out',
              onPressed: () => AppStateScope.of(context).signOut(),
              icon: const Icon(Icons.logout_outlined),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.home_outlined), text: 'Home controls'),
              Tab(icon: Icon(Icons.build_outlined), text: 'Installer tools'),
              Tab(icon: Icon(Icons.group_outlined), text: 'Users'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            MainShell(),
            InstallerPortalScreen(),
            InstallerUsersScreen(),
          ],
        ),
      ),
    );
  }
}
