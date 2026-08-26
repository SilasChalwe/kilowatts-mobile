import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/metric_card.dart';
import '../../../core/widgets/responsive_content.dart';
import '../../system/models/system_state_model.dart';

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
          label: 'Available power',
          value: Formatters.power(state.availablePowerW),
          icon: Icons.bolt_outlined,
        ),
        MetricCard(
          label: 'Committed power',
          value: Formatters.power(state.committedPowerW),
          icon: Icons.power_outlined,
        ),
        MetricCard(
          label: 'Fixed loads',
          value: Formatters.power(state.fixedLoadPowerW),
          icon: Icons.push_pin_outlined,
        ),
        MetricCard(
          label: 'Automatic loads',
          value: Formatters.power(state.autoLoadPowerW),
          icon: Icons.auto_mode_outlined,
        ),
      ],
    );
  }
}
