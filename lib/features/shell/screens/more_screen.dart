import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/responsive_content.dart';
import '../../admin/screens/installer_console_screen.dart';
import '../../admin/screens/installer_operations_screen.dart';
import '../../admin/screens/installer_users_screen.dart';
import '../../battery/screens/battery_power_screen.dart';
import '../../history/screens/history_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../../settings/widgets/settings_tile.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key, this.installerMode = false});

  final bool installerMode;

  Future<void> _signOut(BuildContext context) async {
    final appState = AppStateScope.of(context);
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Sign out?',
      message: 'You will need to sign in again to control this installation.',
      confirmLabel: 'Sign out',
      isDestructive: true,
    );
    if (!confirmed) return;

    await appState.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.root, (_) => false);
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final email = appState.currentUser?.email;

    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ResponsiveContent(
            maxWidth: 760,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PageHeader(
                  title: 'Account & tools',
                  subtitle: email == null
                      ? 'System settings and secondary tools.'
                      : 'Signed in as $email',
                ),
                const SizedBox(height: AppSpacing.lg),
                const Text('ENERGY', style: AppTextStyles.overline),
                const SizedBox(height: AppSpacing.xs),
                SettingsTile(
                  icon: Icons.battery_charging_full_outlined,
                  title: 'Battery & power',
                  subtitle: 'State of charge, available power and live trend',
                  onTap: () => _open(context, const BatteryPowerScreen()),
                ),
                const SizedBox(height: AppSpacing.xs),
                SettingsTile(
                  icon: Icons.insights_outlined,
                  title: 'History & reports',
                  subtitle: 'Session usage trends and system events',
                  onTap: () => _open(context, const HistoryScreen()),
                ),
                if (installerMode) ...[
                  const SizedBox(height: AppSpacing.lg),
                  const Text('INSTALLATION', style: AppTextStyles.overline),
                  const SizedBox(height: AppSpacing.xs),
                  SettingsTile(
                    icon: Icons.build_outlined,
                    title: 'Installer console',
                    subtitle: 'Connection, battery, nodes and load commissioning',
                    onTap: () => _open(context, const InstallerConsoleScreen()),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  SettingsTile(
                    icon: Icons.tune_outlined,
                    title: 'System operations',
                    subtitle: 'Run and schedule Best-First optimization',
                    onTap: () => _open(context, const InstallerOperationsScreen()),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  SettingsTile(
                    icon: Icons.group_outlined,
                    title: 'Users & access',
                    subtitle: 'Manage homeowners and installer permissions',
                    onTap: () => _open(context, const InstallerUsersScreen()),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                const Text('ACCOUNT', style: AppTextStyles.overline),
                const SizedBox(height: AppSpacing.xs),
                SettingsTile(
                  icon: Icons.settings_outlined,
                  title: 'Settings',
                  subtitle: 'Connection, account and application preferences',
                  onTap: () => _open(context, const SettingsScreen()),
                ),
                const SizedBox(height: AppSpacing.xs),
                SettingsTile(
                  icon: Icons.logout_rounded,
                  title: 'Sign out',
                  isDestructive: true,
                  onTap: () => _signOut(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
