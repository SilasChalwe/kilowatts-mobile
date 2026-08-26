import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/page_header.dart';
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
      message: 'You will need to sign in again to control your system.',
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
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                const PageHeader(
                  title: 'More',
                  subtitle: 'Reports, settings and account options.',
                ),
                const SizedBox(height: AppSpacing.lg),
                if (installerMode) ...[
                  const Text('INSTALLATION', style: AppTextStyles.caption),
                  const SizedBox(height: AppSpacing.xs),
                  SettingsTile(
                    icon: Icons.build_outlined,
                    title: 'Installer console',
                    subtitle: 'Connection, battery, safety, nodes and loads',
                    onTap: () => _open(context, const InstallerConsoleScreen()),
                  ),
                  SettingsTile(
                    icon: Icons.tune_outlined,
                    title: 'System operations',
                    subtitle: 'Optimization and Central controls',
                    onTap: () => _open(context, const InstallerOperationsScreen()),
                  ),
                  SettingsTile(
                    icon: Icons.group_outlined,
                    title: 'Users & access',
                    subtitle: 'Homeowners and installer accounts',
                    onTap: () => _open(context, const InstallerUsersScreen()),
                  ),
                  const Divider(height: AppSpacing.xl),
                ],
                const Text('SYSTEM', style: AppTextStyles.caption),
                const SizedBox(height: AppSpacing.xs),
                SettingsTile(
                  icon: Icons.battery_charging_full_outlined,
                  title: 'Battery & power',
                  subtitle: 'State of charge, capacity and power trend',
                  onTap: () => _open(context, const BatteryPowerScreen()),
                ),
                SettingsTile(
                  icon: Icons.bar_chart_outlined,
                  title: 'History & reports',
                  subtitle: 'Usage trends and event history',
                  onTap: () => _open(context, const HistoryScreen()),
                ),
                SettingsTile(
                  icon: Icons.settings_outlined,
                  title: 'Settings',
                  subtitle: 'Account, connection and app preferences',
                  onTap: () => _open(context, const SettingsScreen()),
                ),
                const Divider(height: AppSpacing.xl),
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
