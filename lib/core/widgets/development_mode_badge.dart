import 'package:flutter/material.dart';

import '../app_state/app_state_scope.dart';
import 'status_badge.dart';

/// The one place "DEVELOPMENT MODE" is rendered — reads
/// [SystemStateModel.operatingEnvironment] so every screen that shows this
/// badge, rather than each computing its own check. Central serves
/// simulated battery/power readings across the board while a Development
/// Session is active (see INA219Monitor::setDevelopmentOverride() in the
/// firmware), so a homeowner must never be able to mistake that data for
/// real production readings. Renders nothing at all in PRODUCTION — this
/// is a warning for an unusual state, not a permanent status indicator.
class DevelopmentModeBadge extends StatelessWidget {
  const DevelopmentModeBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    return ValueListenableBuilder(
      valueListenable: appState.systemState,
      builder: (context, state, _) {
        final isDevelopment = state?.operatingEnvironment == 'DEVELOPMENT';
        if (!isDevelopment) {
          return const SizedBox.shrink();
        }
        return const StatusBadge(
          label: 'DEVELOPMENT MODE',
          tone: StatusTone.warning,
        );
      },
    );
  }
}
