import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../../core/services/mqtt_service.dart' show MqttConnectionStatus;
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/trend_chart_card.dart';
import '../../system/models/system_state_model.dart';
import '../widgets/power_budget_card.dart';
import '../widgets/soc_indicator.dart';

/// The power trend chart is built from samples observed during this app
/// session only (accumulated centrally in [AppState.batteryPowerSamples],
/// not by this screen) — there is no historical-data topic/API yet, so
/// nothing before the app was opened is shown.
class BatteryPowerScreen extends StatelessWidget {
  const BatteryPowerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Battery & Power')),
      body: SafeArea(
        child: ValueListenableBuilder<SystemStateModel?>(
          valueListenable: appState.systemState,
          builder: (context, state, _) {
            if (state == null) {
              return ValueListenableBuilder<MqttConnectionStatus>(
                valueListenable: appState.connectionStatus,
                builder: (context, status, _) {
                  return status == MqttConnectionStatus.connected
                      ? const LoadingIndicator(
                          message: 'Waiting for battery telemetry…',
                        )
                      : ErrorState(
                          title: 'System Unavailable',
                          message: 'Reconnect to see battery and power data.',
                          onRetry: appState.connectMqtt,
                        );
                },
              );
            }

            return ValueListenableBuilder<List<double>>(
              valueListenable: appState.batteryPowerSamples,
              builder: (context, powerSamples, _) {
                return ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    SocIndicator(state: state),
                    const SizedBox(height: AppSpacing.md),
                    PowerBudgetCard(state: state),
                    const SizedBox(height: AppSpacing.md),
                    TrendChartCard(
                      title: 'Power Trend (This Session)',
                      values: powerSamples,
                      caption: 'Battery power (W), most recent readings',
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
