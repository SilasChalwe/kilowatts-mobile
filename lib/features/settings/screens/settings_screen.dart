import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/services/mqtt_service.dart' show MqttConnectionStatus;
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/section_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../../system/models/system_state_model.dart';
import 'system_connection_settings_screen.dart';
import '../widgets/settings_tile.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
    final appState = AppStateScope.of(context);
    final user = appState.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            SectionCard(
              title: 'Account',
              child: Column(
                children: [
                  SectionRow(label: 'Name', value: user?.displayName ?? '—'),
                  SectionRow(label: 'Email', value: user?.email ?? '—'),
                  SectionRow(
                    label: 'Email Verified',
                    valueWidget: StatusBadge(
                      label: user?.emailVerified == true
                          ? 'Verified'
                          : 'Unverified',
                      tone: user?.emailVerified == true
                          ? StatusTone.positive
                          : StatusTone.warning,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SettingsTile(
              icon: Icons.router_outlined,
              title: 'System connection',
              subtitle: 'Connect this phone to your installed Kilowatts system',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SystemConnectionSettingsScreen(),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SectionCard(
              title: 'System',
              child: Column(
                children: [
                  ValueListenableBuilder<MqttConnectionStatus>(
                    valueListenable: appState.connectionStatus,
                    builder: (context, status, _) {
                      final connected =
                          status == MqttConnectionStatus.connected;
                      return SectionRow(
                        label: 'MQTT Broker',
                        valueWidget: StatusBadge(
                          label: connected ? 'Connected' : 'Not Connected',
                          tone: connected
                              ? StatusTone.positive
                              : StatusTone.negative,
                        ),
                      );
                    },
                  ),
                  ValueListenableBuilder<SystemStateModel?>(
                    valueListenable: appState.systemState,
                    builder: (context, state, _) {
                      return Column(
                        children: [
                          SectionRow(
                            label: 'Sensor Source',
                            value: state?.sensorInputSource ?? '—',
                          ),
                          SectionRow(
                            label: 'Fault Count',
                            value: state?.faultCount == null
                                ? '—'
                                : '${state!.faultCount}',
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SectionCard(
              title: 'About',
              child: Column(
                children: [
                  const SectionRow(
                    label: 'App Version',
                    value: AppConstants.appVersion,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
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
