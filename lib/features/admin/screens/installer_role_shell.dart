import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../shell/screens/main_shell.dart';
import 'installer_console_screen.dart';
import 'installer_operations_screen.dart';
import 'installer_users_screen.dart';

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
                  _open(context, const InstallerConsoleScreen());
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
                  subtitle: Text('Review and configure installation'),
                ),
              ),
              PopupMenuItem(
                value: _InstallerAction.operations,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.tune_outlined),
                  title: Text('System operations'),
                  subtitle: Text('Optimization controls'),
                ),
              ),
              PopupMenuItem(
                value: _InstallerAction.users,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.group_outlined),
                  title: Text('Users & access'),
                  subtitle: Text('Homeowners and installers'),
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
                child: Text('Installer workspace', style: AppTextStyles.title),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.home_outlined),
                title: const Text('Home controls'),
                selected: true,
                onTap: () => Navigator.of(context).pop(),
              ),
              ListTile(
                leading: const Icon(Icons.build_outlined),
                title: const Text('Installer console'),
                onTap: () {
                  Navigator.of(context).pop();
                  _open(context, const InstallerConsoleScreen());
                },
              ),
              ListTile(
                leading: const Icon(Icons.tune_outlined),
                title: const Text('System operations'),
                onTap: () {
                  Navigator.of(context).pop();
                  _open(context, const InstallerOperationsScreen());
                },
              ),
              ListTile(
                leading: const Icon(Icons.group_outlined),
                title: const Text('Users & access'),
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
                        'Installer access includes homeowner controls.',
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
