import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/development_mode_badge.dart';
import '../../../core/widgets/metric_card.dart';
import '../../../core/widgets/responsive_content.dart';
import '../../system/models/system_state_model.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);

    return AnimatedBuilder(
      animation: Listenable.merge([
        appState.systemState,
        appState.loads,
        appState.connectionStatus,
        appState.centralAvailability,
        appState.lastLiveSystemUpdate,
      ]),
      builder: (context, _) {
        final state = appState.systemState.value ?? SystemStateModel.empty;
        final isLive = appState.isSystemStateLive;
        final loads = isLive ? appState.loads.value : const [];
        final activeLoads = loads
            .where((load) => load.displayState == true)
            .length;
        final soc = isLive ? state.batterySocPercent : null;
        final loadPowerW = isLive ? state.estimatedTotalLoadPowerW : null;
        final remainingPowerW = isLive ? state.remainingPowerW : null;
        final lowReserve =
            soc != null && soc <= AppConstants.defaultLowBatteryWarningPercent;
        final isDevelopment = state.operatingEnvironment == 'DEVELOPMENT';

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
                        label: 'Battery charge',
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
                        value: Formatters.power(loadPowerW),
                        icon: Icons.electric_meter_outlined,
                      ),
                      MetricCard(
                        label: 'Remaining power',
                        value: Formatters.power(remainingPowerW),
                        icon: Icons.battery_saver_outlined,
                      ),
                      MetricCard(
                        label: 'Loads on',
                        value: '$activeLoads of ${loads.length}',
                        icon: Icons.power_rounded,
                      ),
                    ],
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
