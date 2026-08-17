import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/metric_card.dart';
import '../../system/models/system_state_model.dart';

class PowerBudgetCard extends StatelessWidget {
  const PowerBudgetCard({required this.state, super.key});

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
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: MetricCard(
                label: 'Remaining Power',
                value: Formatters.power(state.remainingPowerW),
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
                label: 'Estimated Load Demand',
                value: Formatters.power(state.estimatedTotalLoadPowerW),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: MetricCard(
                label: 'Committed Power',
                value: Formatters.power(state.committedPowerW),
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
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: MetricCard(
                label: 'Auto Loads',
                value: Formatters.power(state.autoLoadPowerW),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
