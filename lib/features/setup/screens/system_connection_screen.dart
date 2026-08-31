import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../../core/services/mqtt_service.dart' show MqttConnectionStatus;
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/kilowatts_logo.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/section_card.dart';
import '../../../core/widgets/secondary_button.dart';
import '../../../core/widgets/status_badge.dart';
import '../models/setup_session.dart';
import 'discovered_nodes_screen.dart';

/// First screen a first-time user sees after authenticating. This is a
/// connectivity/status screen, not a Wi-Fi provisioning flow — the app has
/// no way to configure the Central Node's network directly.
class SystemConnectionScreen extends StatefulWidget {
  const SystemConnectionScreen({super.key});

  @override
  State<SystemConnectionScreen> createState() => _SystemConnectionScreenState();
}

class _SystemConnectionScreenState extends State<SystemConnectionScreen> {
  final _setupSession = SetupSession();
  bool _didRequestConnect = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didRequestConnect) return;
    _didRequestConnect = true;

    final appState = AppStateScope.of(context);
    if (appState.connectionStatus.value == MqttConnectionStatus.disconnected ||
        appState.connectionStatus.value == MqttConnectionStatus.notConfigured) {
      appState.connectMqtt();
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.lg),
              const KilowattsLogo(size: 96),
              const SizedBox(height: AppSpacing.md),
              const Text('Connecting to Kilowatts', style: AppTextStyles.title),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: SingleChildScrollView(
                  child: AnimatedBuilder(
                    animation: Listenable.merge([
                      appState.connectionStatus,
                      appState.topology,
                    ]),
                    builder: (context, _) {
                      final status = appState.connectionStatus.value;
                      final topology = appState.topology.value;
                      final centralOnline = topology?.central?.online ?? false;

                      return Column(
                        children: [
                          SectionCard(
                            title: 'System Status',
                            child: Column(
                              children: [
                                SectionRow(
                                  label: 'Account Sign-In',
                                  valueWidget: StatusBadge(
                                    label: appState.currentUser != null
                                        ? 'Connected'
                                        : 'Signed out',
                                    tone: appState.currentUser != null
                                        ? StatusTone.positive
                                        : StatusTone.negative,
                                  ),
                                ),
                                SectionRow(
                                  label: 'MQTT Broker',
                                  valueWidget: _mqttBadge(status),
                                ),
                                SectionRow(
                                  label: 'Central Node',
                                  valueWidget: StatusBadge(
                                    label: centralOnline ? 'Online' : 'Waiting',
                                    tone: centralOnline
                                        ? StatusTone.positive
                                        : StatusTone.neutral,
                                  ),
                                ),
                                SectionRow(
                                  label: 'Last Synchronized',
                                  value: Formatters.relativeTime(
                                    topology != null ? DateTime.now() : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          if (status ==
                                  MqttConnectionStatus.authenticationFailure ||
                              status == MqttConnectionStatus.tlsFailure ||
                              status == MqttConnectionStatus.networkFailure ||
                              status == MqttConnectionStatus.notConfigured ||
                              status == MqttConnectionStatus.disconnected)
                            SecondaryButton(
                              label: 'Retry',
                              onPressed: appState.connectMqtt,
                            ),
                          const SizedBox(height: AppSpacing.sm),
                          PrimaryButton(
                            label: 'Continue',
                            onPressed: centralOnline
                                ? () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => DiscoveredNodesScreen(
                                        setupSession: _setupSession,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mqttBadge(MqttConnectionStatus status) {
    switch (status) {
      case MqttConnectionStatus.connected:
        return const StatusBadge(label: 'Connected', tone: StatusTone.positive);
      case MqttConnectionStatus.connecting:
        return const StatusBadge(label: 'Connecting', tone: StatusTone.info);
      case MqttConnectionStatus.reconnecting:
        return const StatusBadge(label: 'Retrying', tone: StatusTone.warning);
      case MqttConnectionStatus.disconnected:
        return const StatusBadge(
          label: 'Disconnected',
          tone: StatusTone.negative,
        );
      case MqttConnectionStatus.authenticationFailure:
        return const StatusBadge(
          label: 'Authentication Failed',
          tone: StatusTone.negative,
        );
      case MqttConnectionStatus.tlsFailure:
        return const StatusBadge(
          label: 'Secure Connection Failed',
          tone: StatusTone.negative,
        );
      case MqttConnectionStatus.networkFailure:
        return const StatusBadge(
          label: 'Network Unavailable',
          tone: StatusTone.negative,
        );
      case MqttConnectionStatus.notConfigured:
        return const StatusBadge(
          label: 'Not Configured',
          tone: StatusTone.neutral,
        );
    }
  }
}
