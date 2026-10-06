import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/responsive_content.dart';
import '../widgets/battery_reserve_card.dart';
import '../widgets/power_budget_card.dart';
import '../widgets/sensor_diagnostics_card.dart';
import '../widgets/soc_indicator.dart';

class BatteryPowerScreen extends StatelessWidget {
  const BatteryPowerScreen({super.key, this.embedded = false});

  final bool embedded;

  Widget _content(BuildContext context) {
    final appState = AppStateScope.of(context);

    return AnimatedBuilder(
      animation: Listenable.merge([
        appState.systemState,
        appState.connectionStatus,
        appState.centralAvailability,
        appState.lastLiveSystemUpdate,
      ]),
      builder: (context, _) {
        final state = appState.systemState.value;
        if (state == null) {
          return ErrorState(
            title: 'Battery data unavailable',
            onRetry: appState.connectMqtt,
          );
        }
        final isLive = appState.isSystemStateLive;

        return SingleChildScrollView(
          child: ResponsiveContent(
            maxWidth: 1280,
            child: ResponsiveCardGrid(
              minCardWidth: 300,
              maxColumns: 1,
              children: [
                SocIndicator(state: state, isLive: isLive),
                BatteryReserveCard(state: state, isLive: isLive),
                PowerBudgetCard(state: state, isLive: isLive),
                SensorDiagnosticsCard(state: state, isLive: isLive),
              ],
            ),
          ),
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
