import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/trend_chart_card.dart';
import '../../system/models/system_state_model.dart';
import '../widgets/power_budget_card.dart';
import '../widgets/soc_indicator.dart';

class BatteryPowerScreen extends StatelessWidget {
  const BatteryPowerScreen({super.key, this.embedded = false});

  final bool embedded;

  Widget _content(BuildContext context, {required bool showPageHeader}) {
    final appState = AppStateScope.of(context);

    return ValueListenableBuilder<SystemStateModel?>(
      valueListenable: appState.systemState,
      builder: (context, state, _) {
        if (state == null) {
          return ErrorState(
            title: 'Battery data unavailable',
            message:
                'Central has not reported battery telemetry yet. Check the system connection and battery sensor.',
            onRetry: appState.connectMqtt,
          );
        }

        return ValueListenableBuilder<List<double>>(
          valueListenable: appState.batteryPowerSamples,
          builder: (context, powerSamples, _) {
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                if (showPageHeader) ...[
                  const PageHeader(
                    title: 'Battery & power',
                    subtitle:
                        'State of charge, available power and recent battery behavior.',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                LayoutBuilder(
                  builder: (context, constraints) {
                    final twoColumns = constraints.maxWidth >= 820;
                    final gap = AppSpacing.md;
                    final width = twoColumns
                        ? (constraints.maxWidth - gap) / 2
                        : constraints.maxWidth;
                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      crossAxisAlignment: WrapCrossAlignment.start,
                      children: [
                        SizedBox(width: width, child: SocIndicator(state: state)),
                        SizedBox(
                          width: width,
                          child: PowerBudgetCard(state: state),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TrendChartCard(
                  title: 'Battery power trend',
                  values: powerSamples,
                  caption: 'Battery power (W) · readings from this app session',
                ),
              ],
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
        child: SafeArea(child: _content(context, showPageHeader: true)),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Battery & power')),
      body: SafeArea(child: _content(context, showPageHeader: false)),
    );
  }
}
