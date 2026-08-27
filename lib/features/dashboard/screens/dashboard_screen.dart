import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../../core/models/telemetry_point.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/development_mode_badge.dart';
import '../../../core/widgets/responsive_content.dart';
import '../../../core/widgets/trend_chart_card.dart';
import '../../system/models/system_state_model.dart';
import '../widgets/overview_kpi_card.dart';
import '../widgets/overview_power_allocation_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, this.onViewAllAlerts});

  // Retained for source compatibility. Alerts have their own destination and
  // are intentionally not duplicated on Overview.
  final VoidCallback? onViewAllAlerts;

  List<TelemetryPoint> _lastDay(List<TelemetryPoint> points) {
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    return points
        .where((point) => !point.timestamp.isBefore(cutoff))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);

    return AnimatedBuilder(
      animation: Listenable.merge([
        appState.systemState,
        appState.loads,
        appState.activeLoadPowerHistory,
      ]),
      builder: (context, _) {
        final state = appState.systemState.value ?? SystemStateModel.empty;
        final loads = appState.loads.value;
        final activeLoads = loads.where((load) => load.displayState == true).length;
        final isDevelopment = state.operatingEnvironment == 'DEVELOPMENT';
        final batteryDetail =
            '${Formatters.voltage(state.batteryVoltage)} · ${Formatters.current(state.batteryCurrent)}';
        final automaticBudget = Formatters.power(state.availablePowerW);

        return SafeArea(
          child: SingleChildScrollView(
            child: ResponsiveContent(
              maxWidth: 1320,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isDevelopment) ...[
                    const DevelopmentModeBadge(),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  ResponsiveCardGrid(
                    minCardWidth: 220,
                    maxColumns: 4,
                    children: [
                      OverviewKpiCard(
                        label: 'Battery reserve',
                        value: Formatters.percent(state.batterySocPercent),
                        icon: Icons.battery_5_bar_rounded,
                        supportingText: batteryDetail,
                      ),
                      OverviewKpiCard(
                        label: 'Active load power',
                        value: Formatters.power(state.estimatedTotalLoadPowerW),
                        icon: Icons.electric_meter_outlined,
                        supportingText: 'Fixed + automatic loads',
                      ),
                      OverviewKpiCard(
                        label: 'Auto budget remaining',
                        value: Formatters.power(state.remainingPowerW),
                        icon: Icons.battery_saver_outlined,
                        supportingText: automaticBudget == Formatters.unavailable
                            ? 'Automatic budget unavailable'
                            : 'of $automaticBudget budget',
                      ),
                      OverviewKpiCard(
                        label: 'Loads on',
                        value: '$activeLoads',
                        icon: Icons.power_settings_new_rounded,
                        supportingText: loads.length == 1
                            ? '1 configured load'
                            : '${loads.length} configured loads',
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final chart = TrendChartCard(
                        title: 'Active load power · 24h',
                        points: _lastDay(appState.activeLoadPowerHistory.value),
                        unit: 'W',
                        minimumY: 0,
                        chartHeight: constraints.maxWidth >= 900 ? 286 : 220,
                        caption:
                            'Persistent history on this device. The newest reading is highlighted.',
                      );
                      final allocation = OverviewPowerAllocationCard(state: state);

                      if (constraints.maxWidth < 900) {
                        return Column(
                          children: [
                            chart,
                            const SizedBox(height: AppSpacing.md),
                            allocation,
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 2, child: chart),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(child: allocation),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
