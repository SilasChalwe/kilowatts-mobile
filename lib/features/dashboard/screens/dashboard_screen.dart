import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../../core/services/mqtt_service.dart' show MqttConnectionStatus;
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/live_status_badge.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../system/models/topology_model.dart';
import '../../settings/screens/system_connection_settings_screen.dart';
import '../widgets/battery_summary.dart';
import '../widgets/load_summary.dart';
import '../widgets/power_summary.dart';
import '../widgets/recent_alerts.dart';
import '../widgets/system_health_summary.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, this.onViewAllAlerts});

  final VoidCallback? onViewAllAlerts;

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);

    return AnimatedBuilder(
      animation: Listenable.merge([
        appState.systemState,
        appState.loads,
        appState.topology,
        appState.alerts,
        appState.connectionStatus,
      ]),
      builder: (context, _) {
        final state = appState.systemState.value;
        final connectionStatus = appState.connectionStatus.value;

        if (state == null) {
          if (connectionStatus == MqttConnectionStatus.notConfigured) {
            return ErrorState(
              title: 'Connect your system',
              message:
                  'Set up this phone using the broker details supplied by your installer.',
              actionLabel: 'Set up connection',
              onRetry: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SystemConnectionSettingsScreen(),
                ),
              ),
            );
          }
          if (connectionStatus == MqttConnectionStatus.connecting ||
              connectionStatus == MqttConnectionStatus.reconnecting) {
            return const LoadingIndicator(
              message: 'Connecting to your system…',
            );
          }
          return ErrorState(
            title: 'No System Data Yet',
            message:
                'Waiting for the Central Node to publish its first update.',
            onRetry: appState.connectMqtt,
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Dashboard', style: AppTextStyles.title),
                    const Spacer(),
                    const LiveStatusBadge(),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Expanded(
                  child: ListView(
                    children: [
                      BatterySummary(state: state),
                      const SizedBox(height: AppSpacing.md),
                      PowerSummary(state: state),
                      const SizedBox(height: AppSpacing.md),
                      LoadSummary(
                        loads: appState.loads.value,
                        topology:
                            appState.topology.value ?? TopologyModel.empty,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      SystemHealthSummary(
                        connectionStatus: connectionStatus,
                        topology: appState.topology.value,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      RecentAlerts(
                        alerts: appState.alerts.value,
                        onViewAll: onViewAllAlerts,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
