import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/metric_card.dart';
import '../../system/models/system_state_model.dart';

class PowerSummary extends StatelessWidget {
  const PowerSummary({required this.state, super.key});

  final SystemStateModel state;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: MetricCard(
                label: 'Available Power',
                value: Formatters.power(state.availablePowerW),
                icon: Icons.bolt_outlined,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: MetricCard(
                label: 'Committed Power',
                value: Formatters.power(state.committedPowerW),
                icon: Icons.power_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: MetricCard(
                label: 'Fixed Loads',
                value: Formatters.power(state.fixedLoadPowerW),
                icon: Icons.push_pin_outlined,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: MetricCard(
                label: 'Auto Loads',
                value: Formatters.power(state.autoLoadPowerW),
                icon: Icons.auto_mode_outlined,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
