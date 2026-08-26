import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/services/mqtt_service.dart' show MqttConnectionStatus;
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/section_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../../system/models/system_state_model.dart';
import 'system_connection_settings_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, this.embedded = false});

  final bool embedded;

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

  Widget _content(BuildContext context, {required bool showPageHeader}) {
    final appState = AppStateScope.of(context);
    final user = appState.currentUser;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        if (showPageHeader) ...[
          const PageHeader(
            title: 'Settings',
            subtitle: 'Account, connection and application information.',
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        LayoutBuilder(
          builder: (context, constraints) {
            final twoColumns = constraints.maxWidth >= 900;
            final gap = AppSpacing.md;
            final width = twoColumns
                ? (constraints.maxWidth - gap) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              crossAxisAlignment: WrapCrossAlignment.start,
              children: [
                SizedBox(
                  width: width,
                  child: SectionCard(
                    title: 'Account',
                    child: Column(
                      children: [
                        SectionRow(
                          label: 'Name',
                          value: user?.displayName ?? 'Not set',
                        ),
                        SectionRow(label: 'Email', value: user?.email ?? '—'),
                        SectionRow(
                          label: 'Email status',
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
                ),
                SizedBox(
                  width: width,
                  child: SectionCard(
                    title: 'System connection',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ValueListenableBuilder<MqttConnectionStatus>(
                          valueListenable: appState.connectionStatus,
                          builder: (context, status, _) {
                            final connected =
                                status == MqttConnectionStatus.connected;
                            return SectionRow(
                              label: 'MQTT broker',
                              valueWidget: StatusBadge(
                                label: connected ? 'Connected' : 'Not connected',
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
                                  label: 'Sensor source',
                                  value: state?.sensorInputSource ?? 'Unavailable',
                                ),
                                SectionRow(
                                  label: 'Fault count',
                                  value: state?.faultCount == null
                                      ? '—'
                                      : '${state!.faultCount}',
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    const SystemConnectionSettingsScreen(),
                              ),
                            ),
                            icon: const Icon(Icons.router_outlined, size: 18),
                            label: const Text('Manage connection'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: const SectionCard(
                    title: 'About Kilowatts',
                    child: Column(
                      children: [
                        SectionRow(
                          label: 'App version',
                          value: AppConstants.appVersion,
                        ),
                        SectionRow(
                          label: 'Platform role',
                          value: 'Energy monitoring & load management',
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: SectionCard(
                    title: 'Account actions',
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Sign out of this device without changing the system configuration.',
                            style: AppTextStyles.caption,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                          ),
                          onPressed: () => _signOut(context),
                          icon: const Icon(Icons.logout_rounded, size: 18),
                          label: const Text('Sign out'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (embedded) {
      return Material(
        color: Colors.transparent,
        child: SafeArea(child: _content(context, showPageHeader: true)),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(child: _content(context, showPageHeader: false)),
    );
  }
}
