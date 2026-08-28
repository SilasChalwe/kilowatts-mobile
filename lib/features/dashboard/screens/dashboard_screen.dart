import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/telemetry_point.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/development_mode_badge.dart';
import '../../../core/widgets/metric_card.dart';
import '../../../core/widgets/responsive_content.dart';
import '../../../core/widgets/section_card.dart';
import '../../../core/widgets/trend_chart_card.dart';
import '../../loads/models/load_model.dart';
import '../../system/models/system_state_model.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, this.onViewAllAlerts});

  // Retained for compatibility with older shell call sites. Alerts have their
  // own primary destination and are intentionally not duplicated on Overview.
  final VoidCallback? onViewAllAlerts;

  List<TelemetryPoint> _lastHour(List<TelemetryPoint> points) {
    final cutoff = DateTime.now().subtract(const Duration(hours: 1));
    return points
        .where((point) => !point.timestamp.isBefore(cutoff))
        .toList(growable: false);
  }

  String _batteryInput(SystemStateModel state) {
    switch (state.sensorInputSource?.toUpperCase()) {
      case 'HARDWARE':
        return 'INA219';
      case 'SIMULATED':
        return 'Simulation';
      case 'NONE':
        return 'Not configured';
      default:
        return 'Unavailable';
    }
  }

  String _reserveStatus(double? soc) {
    if (soc == null) return 'Unavailable';
    if (soc <= AppConstants.defaultLowBatteryWarningPercent) {
      return 'Low reserve';
    }
    return 'Normal';
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
        final fixedLoads = loads.where((load) => load.mode == LoadMode.fixed).length;
        final automaticLoads = loads.where((load) => load.mode == LoadMode.auto).length;
        final soc = state.batterySocPercent;
        final lowReserve = soc != null &&
            soc <= AppConstants.defaultLowBatteryWarningPercent;
        final history = _lastHour(appState.activeLoadPowerHistory.value);
        final isDevelopment = state.operatingEnvironment == 'DEVELOPMENT';
        final batteryDetail =
            '${Formatters.voltage(state.batteryVoltage)} · ${Formatters.current(state.batteryCurrent)}';
        final automaticBudget = Formatters.power(state.availablePowerW);

        return SafeArea(
          child: SingleChildScrollView(
            child: ResponsiveContent(
              maxWidth: 1280,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isDevelopment) ...[
                    const DevelopmentModeBadge(),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  ResponsiveCardGrid(
                    minCardWidth: 150,
                    maxColumns: 4,
                    gap: AppSpacing.sm,
                    children: [
                      MetricCard(
                        label: 'Battery reserve',
                        value: Formatters.percent(soc),
                        icon: soc == null
                            ? Icons.help_outline_rounded
                            : lowReserve
                                ? Icons.battery_alert_outlined
                                : Icons.battery_charging_full_outlined,
                        valueColor: lowReserve ? AppColors.warning : null,
                      ),
                      MetricCard(
                        label: 'Active load power',
                        value: Formatters.power(state.estimatedTotalLoadPowerW),
                        icon: Icons.electric_meter_outlined,
                      ),
                      MetricCard(
                        label: 'Remaining auto budget',
                        value: Formatters.power(state.remainingPowerW),
                        icon: Icons.battery_saver_outlined,
                      ),
                      MetricCard(
                        label: 'Loads on',
                        value: '$activeLoads',
                        icon: Icons.power_rounded,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final chart = TrendChartCard(
                        title: 'Load power · last hour',
                        points: history,
                        unit: 'W',
                        minimumY: 0,
                        caption:
                            'Fixed ON + automatic loads currently selected by Central. The newest reading is highlighted.',
                      );

                      final details = Column(
                        children: [
                          SectionCard(
                            title: 'Power allocation',
                            child: Column(
                              children: [
                                SectionRow(
                                  label: 'Automatic budget',
                                  value: Formatters.power(state.availablePowerW),
                                ),
                                SectionRow(
                                  label: 'Fixed loads',
                                  value: Formatters.power(state.fixedLoadPowerW),
                                ),
                                SectionRow(
                                  label: 'AUTO selected',
                                  value: Formatters.power(state.autoLoadPowerW),
                                ),
                                SectionRow(
                                  label: 'Remaining',
                                  value: Formatters.power(state.remainingPowerW),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          SectionCard(
                            title: 'System snapshot',
                            child: Column(
                              children: [
                                SectionRow(
                                  label: 'Battery voltage',
                                  value: Formatters.voltage(state.batteryVoltage),
                                ),
                                SectionRow(
                                  label: 'Battery current',
                                  value: Formatters.current(state.batteryCurrent),
                                ),
                                SectionRow(
                                  label: 'Battery input',
                                  value: _batteryInput(state),
                                ),
                                SectionRow(
                                  label: 'Reserve status',
                                  value: _reserveStatus(soc),
                                ),
                                SectionRow(
                                  label: 'Load mix',
                                  value:
                                      '$fixedLoads fixed · $automaticLoads automatic',
                                ),
                              ],
                            ),
                          ),
                        ],
                      );

                      if (constraints.maxWidth < 720) {
                        return Column(
                          children: [
                            chart,
                            const SizedBox(height: AppSpacing.md),
                            details,
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 2, child: chart),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(child: details),
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
