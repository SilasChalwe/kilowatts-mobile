import 'package:flutter/material.dart';

import '../app_state/app_state_scope.dart';
import 'status_badge.dart';

/// The one place "Live"/"Stale" is rendered — reads [AppState]'s freshness
/// signal instead of every screen computing its own timeout. Firmware
/// publishes no `state/availability` topic yet, so this reflects retained
/// state freshness plus MQTT connectivity only, not a distinct
/// "Central offline" signal.
class LiveStatusBadge extends StatelessWidget {
  const LiveStatusBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    return AnimatedBuilder(
      animation: Listenable.merge([
        appState.connectionStatus,
        appState.lastLiveSystemUpdate,
      ]),
      builder: (context, _) {
        final isLive = appState.isSystemStateLive;
        return StatusBadge(
          label: isLive ? 'Live' : 'Stale',
          tone: isLive ? StatusTone.positive : StatusTone.warning,
        );
      },
    );
  }
}
