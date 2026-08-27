import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/metric_card.dart';
import '../../../core/widgets/responsive_content.dart';
import '../../system/models/system_state_model.dart';

/// Dashboard power summary.
///
/// The firmware publishes FIXED_ON power and selected AUTO power separately.
/// Active load power is their sum. The old "Committed power" metric was
/// removed because it was sourced from the exact same FIXED_ON value and
/// therefore duplicated the fixed-load metric under another name.
class PowerSummary extends StatelessWidget {
  const PowerSummary({required this.state, super.key});

  final SystemStateModel state;

  @override
  Widget build(BuildContext context) {
    return ResponsiveCardGrid(
      minCardWidth: 165,
      maxColumns: 2,
      children: [
        MetricCard(
          label: 'Active load power',
          value: Formatters.power(state.estimatedTotalLoadPowerW),
          icon: Icons.electric_meter_outlined,
        ),
        MetricCard(
          label: 'Automatic power budget',
          value: Formatters.power(state.availablePowerW),
          icon: Icons.bolt_outlined,
        ),
        MetricCard(
          label: 'Fixed load power',
          value: Formatters.power(state.fixedLoadPowerW),
          icon: Icons.push_pin_outlined,
        ),
        MetricCard(
          label: 'Automatic load power',
          value: Formatters.power(state.autoLoadPowerW),
          icon: Icons.auto_mode_outlined,
        ),
        MetricCard(
          label: 'Remaining auto budget',
          value: Formatters.power(state.remainingPowerW),
          icon: Icons.battery_saver_outlined,
        ),
      ],
    );
  }
}
