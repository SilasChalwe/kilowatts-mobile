import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/responsive_content.dart';
import '../../../core/widgets/section_card.dart';
import '../../../core/widgets/status_badge.dart';
import 'system_connection_settings_screen.dart';
import '../widgets/settings_tile.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, this.embedded = false});

  final bool embedded;

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

  Widget _content(BuildContext context) {
    final appState = AppStateScope.of(context);
    final user = appState.currentUser;

    final accountCard = SectionCard(
      title: 'Account',
      child: Column(
        children: [
          SectionRow(label: 'Name', value: user?.displayName ?? 'Not set'),
          SectionRow(label: 'Email', value: user?.email ?? '—'),
          SectionRow(
            label: 'Email verification',
            valueWidget: StatusBadge(
              label: user?.emailVerified == true ? 'Verified' : 'Unverified',
              tone: user?.emailVerified == true
                  ? StatusTone.positive
                  : StatusTone.warning,
            ),
          ),
        ],
      ),
    );

    final aboutCard = const SectionCard(
      title: 'About',
      child: Column(
        children: [
          SectionRow(label: 'Application', value: 'Kilowatts'),
          SectionRow(label: 'Version', value: AppConstants.appVersion),
        ],
      ),
    );

    return SingleChildScrollView(
      child: ResponsiveContent(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ResponsiveCardGrid(
              minCardWidth: 360,
              maxColumns: 2,
              children: [
                accountCard,
                SettingsTile(
                  icon: Icons.router_outlined,
                  title: 'System connection',
                  subtitle: 'Review or change the MQTT connection used by this device',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SystemConnectionSettingsScreen(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ResponsiveCardGrid(
              minCardWidth: 360,
              maxColumns: 2,
              children: [
                aboutCard,
                SettingsTile(
                  icon: Icons.logout_rounded,
                  title: 'Sign out',
                  subtitle: 'End this account session on the current device',
                  isDestructive: true,
                  onTap: () => _signOut(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (embedded) {
      return Material(
        color: Colors.transparent,
        child: SafeArea(child: _content(context)),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(child: _content(context)),
    );
  }
}
