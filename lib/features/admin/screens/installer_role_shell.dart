import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../shell/screens/main_shell.dart';
import 'installer_operations_screen.dart';
import 'installer_portal_screen.dart';
import 'installer_users_screen.dart';

/// Installer/admin is a superset role, but the homeowner product remains the
/// primary daily-use surface. Installer work opens as focused full-screen
/// workspaces instead of nesting tab navigation around the homeowner shell.
class InstallerRoleShell extends StatelessWidget {
  const InstallerRoleShell({super.key});

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: AppSpacing.md,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kilowatts', style: AppTextStyles.label),
            Text('Installer access', style: AppTextStyles.caption),
          ],
        ),
        actions: [
          PopupMenuButton<_InstallerAction>(
            tooltip: 'Installer actions',
            icon: const Icon(Icons.admin_panel_settings_outlined),
            onSelected: (action) {
              switch (action) {
                case _InstallerAction.console:
                  _open(context, const InstallerPortalScreen());
                  break;
                case _InstallerAction.operations:
                  _open(context, const InstallerOperationsScreen());
                  break;
                case _InstallerAction.users:
                  _open(context, const InstallerUsersScreen());
                  break;
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _InstallerAction.console,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.build_outlined),
                  title: Text('Installer console'),
                  subtitle: Text('Nodes, loads, battery and MQTT'),
                ),
              ),
              PopupMenuItem(
                value: _InstallerAction.operations,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.tune_outlined),
                  title: Text('System operations'),
                  subtitle: Text('Run optimization and runtime controls'),
                ),
              ),
              PopupMenuItem(
                value: _InstallerAction.users,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.group_outlined),
                  title: Text('Users & access'),
                  subtitle: Text('Homeowners and installer roles'),
                ),
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Installer workspace', style: AppTextStyles.title),
                    SizedBox(height: 4),
                    Text(
                      'Home controls plus installation administration',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.home_outlined),
                title: const Text('Home controls'),
                subtitle: const Text('Dashboard, loads, topology and alerts'),
                selected: true,
                onTap: () => Navigator.of(context).pop(),
              ),
              ListTile(
                leading: const Icon(Icons.build_outlined),
                title: const Text('Installer console'),
                subtitle: const Text('Commission and configure hardware'),
                onTap: () {
                  Navigator.of(context).pop();
                  _open(context, const InstallerPortalScreen());
                },
              ),
              ListTile(
                leading: const Icon(Icons.tune_outlined),
                title: const Text('System operations'),
                subtitle: const Text('Optimization and Central controls'),
                onTap: () {
                  Navigator.of(context).pop();
                  _open(context, const InstallerOperationsScreen());
                },
              ),
              ListTile(
                leading: const Icon(Icons.group_outlined),
                title: const Text('Users & access'),
                subtitle: const Text('Manage homeowners and installers'),
                onTap: () {
                  Navigator.of(context).pop();
                  _open(context, const InstallerUsersScreen());
                },
              ),
              const Spacer(),
              Container(
                margin: const EdgeInsets.all(AppSpacing.md),
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.verified_user_outlined, size: 18),
                    SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        'Installer role includes every homeowner operation.',
                        style: AppTextStyles.caption,
                      ),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.logout_outlined),
                title: const Text('Sign out'),
                onTap: () => AppStateScope.of(context).signOut(),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
      body: const MainShell(),
    );
  }
}

enum _InstallerAction { console, operations, users }
