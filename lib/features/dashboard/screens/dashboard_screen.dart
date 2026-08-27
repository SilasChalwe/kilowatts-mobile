import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/development_mode_badge.dart';
import '../../../core/widgets/responsive_content.dart';
import '../../system/models/system_state_model.dart';
import '../../system/models/topology_model.dart';
import '../widgets/battery_summary.dart';
import '../widgets/load_summary.dart';
import '../widgets/power_summary.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, this.onViewAllAlerts});

  // Kept for source compatibility with older shell call sites. Alerts now have
  // their own destination and are not duplicated on Overview.
  final VoidCallback? onViewAllAlerts;

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);

    return AnimatedBuilder(
      animation: Listenable.merge([
        appState.systemState,
        appState.loads,
        appState.topology,
      ]),
      builder: (context, _) {
        final state = appState.systemState.value ?? SystemStateModel.empty;
        final topology = appState.topology.value ?? TopologyModel.empty;
        final isDevelopment = state.operatingEnvironment == 'DEVELOPMENT';

        return SafeArea(
          child: SingleChildScrollView(
            child: ResponsiveContent(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isDevelopment) ...[
                    const DevelopmentModeBadge(),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  ResponsiveCardGrid(
                    minCardWidth: 360,
                    maxColumns: 3,
                    children: [
                      BatterySummary(state: state),
                      PowerSummary(state: state),
                      LoadSummary(
                        loads: appState.loads.value,
                        topology: topology,
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
