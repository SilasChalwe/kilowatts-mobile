import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../../core/services/mqtt_service.dart' show MqttConnectionStatus;
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/development_mode_badge.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/live_status_badge.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/responsive_content.dart';
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

        Widget stateBody;
        if (state == null) {
          if (connectionStatus == MqttConnectionStatus.notConfigured) {
            stateBody = ErrorState(
              icon: Icons.router_outlined,
              title: 'Connect this device',
              message:
                  'Add the MQTT connection supplied for this installation to begin receiving live telemetry.',
              actionLabel: 'Set up connection',
              onRetry: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SystemConnectionSettingsScreen(),
                ),
              ),
            );
          } else if (connectionStatus == MqttConnectionStatus.connecting ||
              connectionStatus == MqttConnectionStatus.reconnecting) {
            stateBody = const LoadingIndicator(
              message: 'Connecting to your Kilowatts system…',
            );
          } else {
            stateBody = ErrorState(
              icon: Icons.cloud_off_outlined,
              title: 'Waiting for Central',
              message:
                  'The connection is configured, but Central has not published a live system update yet.',
              onRetry: appState.connectMqtt,
            );
          }
        } else {
          final topology = appState.topology.value ?? TopologyModel.empty;
          stateBody = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SystemHealthSummary(
                connectionStatus: connectionStatus,
                topology: appState.topology.value,
              ),
              const SizedBox(height: AppSpacing.md),
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
                  const PageHeader(
                    title: 'Overview',
                    subtitle:
                        'Live energy, load allocation and installation health.',
                    actions: [
                      DevelopmentModeBadge(),
                      LiveStatusBadge(),
                    ],
                  ),
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
