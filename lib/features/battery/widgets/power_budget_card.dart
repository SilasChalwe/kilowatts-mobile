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
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.sm,
      crossAxisSpacing: AppSpacing.sm,
      childAspectRatio: 2.2,
      children: [
        MetricCard(
          label: 'Available Power',
          value: Formatters.power(state.availablePowerW),
        ),
        MetricCard(
          label: 'Remaining Power',
          value: Formatters.power(state.remainingPowerW),
        ),
        MetricCard(
          label: 'Estimated Load Demand',
          value: Formatters.power(state.estimatedTotalLoadPowerW),
        ),
        MetricCard(
          label: 'Committed Power',
          value: Formatters.power(state.committedPowerW),
        ),
        MetricCard(
          label: 'Fixed Loads',
          value: Formatters.power(state.fixedLoadPowerW),
        ),
        MetricCard(
          label: 'Auto Loads',
          value: Formatters.power(state.autoLoadPowerW),
        ),
      ],
    );
  }
}
