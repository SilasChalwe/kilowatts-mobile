import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/responsive_content.dart';
import '../../../core/widgets/trend_chart_card.dart';
import '../../system/models/system_state_model.dart';
import '../widgets/power_budget_card.dart';
import '../widgets/soc_indicator.dart';

/// The power trend chart is built from samples observed during this app
/// session only. Nothing before the app was opened is invented or backfilled.
class BatteryPowerScreen extends StatelessWidget {
  const BatteryPowerScreen({super.key, this.embedded = false});

  final bool embedded;

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

        return ValueListenableBuilder<List<double>>(
          valueListenable: appState.batteryPowerSamples,
          builder: (context, powerSamples, _) {
            return SingleChildScrollView(
              child: ResponsiveContent(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ResponsiveCardGrid(
                      minCardWidth: 360,
                      maxColumns: 2,
                      children: [
                        SocIndicator(state: state),
                        PowerBudgetCard(state: state),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TrendChartCard(
                      title: 'Battery power · this session',
                      values: powerSamples,
                      caption: 'Recent battery power readings',
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
