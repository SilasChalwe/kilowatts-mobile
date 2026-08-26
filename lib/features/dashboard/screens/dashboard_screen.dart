import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../../core/services/mqtt_service.dart' show MqttConnectionStatus;
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/development_mode_badge.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/live_status_badge.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/page_header.dart';
import '../../settings/screens/system_connection_settings_screen.dart';
import '../../system/models/topology_model.dart';
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
              title: 'Connect your Kilowatts system',
              message:
                  'Add the broker details for this installation to start receiving live energy and load data.',
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
            return const LoadingIndicator(message: 'Connecting to your system…');
          }
          return ErrorState(
            title: 'Waiting for Central',
            message:
                'The app is connected but has not received a system update yet.',
            onRetry: appState.connectMqtt,
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PageHeader(
                  title: 'Overview',
                  subtitle: 'Live energy, loads and system health.',
                  actions: [
                    DevelopmentModeBadge(),
                    LiveStatusBadge(),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Expanded(
                  child: ListView(
                    children: [
                      SystemHealthSummary(
                        connectionStatus: connectionStatus,
                        topology: appState.topology.value,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final gap = AppSpacing.md;
                          final columns = constraints.maxWidth >= 1180
                              ? 3
                              : constraints.maxWidth >= 760
                                  ? 2
                                  : 1;
                          final width =
                              (constraints.maxWidth - gap * (columns - 1)) /
                                  columns;
                          return Wrap(
                            spacing: gap,
                            runSpacing: gap,
                            children: [
                              SizedBox(
                                width: width,
                                child: BatterySummary(state: state),
                              ),
                              SizedBox(
                                width: width,
                                child: PowerSummary(state: state),
                              ),
                              SizedBox(
                                width: width,
                                child: LoadSummary(
                                  loads: appState.loads.value,
                                  topology: appState.topology.value ??
                                      TopologyModel.empty,
                                ),
                              ),
                            ],
                          );
                        },
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
