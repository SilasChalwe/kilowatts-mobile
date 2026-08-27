import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../../core/models/telemetry_point.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/responsive_content.dart';
import '../../../core/widgets/trend_chart_card.dart';
import '../../system/models/system_state_model.dart';
import '../widgets/power_budget_card.dart';
import '../widgets/soc_indicator.dart';

class BatteryPowerScreen extends StatelessWidget {
  const BatteryPowerScreen({super.key, this.embedded = false});

  final bool embedded;

  List<TelemetryPoint> _lastDay(List<TelemetryPoint> points) {
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    return points
        .where((point) => !point.timestamp.isBefore(cutoff))
        .toList(growable: false);
  }

  Widget _content(BuildContext context) {
    final appState = AppStateScope.of(context);

    return ValueListenableBuilder<SystemStateModel?>(
      valueListenable: appState.systemState,
      builder: (context, state, _) {
        if (state == null) {
          return ErrorState(
            title: 'Battery data unavailable',
            message: 'Central has not published battery telemetry.',
            onRetry: appState.connectMqtt,
          );
        }

        return ValueListenableBuilder<List<TelemetryPoint>>(
          valueListenable: appState.batteryPowerHistory,
          builder: (context, history, _) {
            return SingleChildScrollView(
              child: ResponsiveContent(
                maxWidth: 1280,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ResponsiveCardGrid(
                      minCardWidth: 300,
                      maxColumns: 2,
                      children: [
                        SocIndicator(state: state),
                        PowerBudgetCard(state: state),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TrendChartCard(
                      title: 'Battery power · 24h',
                      points: _lastDay(history),
                      unit: 'W',
                      caption:
                          'Persistent battery power history stored on this device.',
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
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
      appBar: AppBar(title: const Text('Battery & power')),
      body: SafeArea(child: _content(context)),
    );
  }
}
