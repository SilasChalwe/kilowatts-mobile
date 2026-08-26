import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../../core/services/mqtt_service.dart' show MqttConnectionStatus;
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/development_mode_badge.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/responsive_content.dart';
import '../../settings/screens/system_connection_settings_screen.dart';
import '../../system/models/topology_model.dart';
import '../widgets/battery_summary.dart';
import '../widgets/load_summary.dart';
import '../widgets/power_summary.dart';
import '../widgets/recent_alerts.dart';

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

        Widget stateBody;
        if (state == null) {
          if (connectionStatus == MqttConnectionStatus.notConfigured) {
            stateBody = ErrorState(
              icon: Icons.router_outlined,
              title: 'System setup required',
              message: 'Add the connection details for this installation.',
              actionLabel: 'Set up connection',
              onRetry: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SystemConnectionSettingsScreen(),
                ),
              ),
            );
          } else if (connectionStatus == MqttConnectionStatus.connecting ||
              connectionStatus == MqttConnectionStatus.reconnecting) {
            stateBody = const LoadingIndicator(message: 'Connecting…');
          } else {
            stateBody = ErrorState(
              icon: Icons.cloud_off_outlined,
              title: 'No telemetry available',
              message: 'Connect the system to load operating data.',
              actionLabel: 'Reconnect',
              onRetry: appState.connectMqtt,
            );
          }
        } else {
          final topology = appState.topology.value ?? TopologyModel.empty;
          final isDevelopment = state.operatingEnvironment == 'DEVELOPMENT';

          stateBody = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isDevelopment) ...[
                const DevelopmentModeBadge(),
                const SizedBox(height: AppSpacing.md),
              ],
              ResponsiveCardGrid(
                minCardWidth: 420,
                maxColumns: 2,
                children: [
                  Column(
                    children: [
                      BatterySummary(state: state),
                      const SizedBox(height: AppSpacing.md),
                      LoadSummary(
                        loads: appState.loads.value,
                        topology: topology,
                      ),
                    ],
                  ),
                  PowerSummary(state: state),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              RecentAlerts(
                alerts: appState.alerts.value,
                onViewAll: onViewAllAlerts,
              ),
            ],
          );
        }

        return SafeArea(
          child: SingleChildScrollView(
            child: ResponsiveContent(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const PageHeader(title: 'Overview'),
                  const SizedBox(height: AppSpacing.lg),
                  stateBody,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
