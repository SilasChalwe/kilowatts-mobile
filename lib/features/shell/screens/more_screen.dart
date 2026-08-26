import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../battery/screens/battery_power_screen.dart';
import '../../history/screens/history_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../../settings/widgets/settings_tile.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    final appState = AppStateScope.of(context);
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Sign Out',
      message: 'You will need to sign in again to control your system.',
      confirmLabel: 'Sign Out',
      isDestructive: true,
    );
    if (!confirmed) return;

    await appState.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.root, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            SettingsTile(
              icon: Icons.battery_charging_full_outlined,
              title: 'Battery & Power',
              subtitle: 'State of charge, capacity and power trend',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const BatteryPowerScreen()),
              ),
            ),
            SettingsTile(
              icon: Icons.bar_chart_outlined,
              title: 'History / Reports',
              subtitle: 'Usage trends and event history',
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const HistoryScreen())),
            ),
            SettingsTile(
              icon: Icons.settings_outlined,
              title: 'Settings',
              subtitle: 'Account, system and app preferences',
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
            ),
            const Divider(height: AppSpacing.xl),
            SettingsTile(
              icon: Icons.logout_rounded,
              title: 'Logout',
              isDestructive: true,
              onTap: () => _signOut(context),
            ),
          ],
        ),
      ),
    );
  }
}
