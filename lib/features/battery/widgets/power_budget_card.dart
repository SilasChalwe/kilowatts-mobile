import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/section_card.dart';
import '../../system/models/system_state_model.dart';

class PowerBudgetCard extends StatelessWidget {
  const PowerBudgetCard({required this.state, super.key});

  final SystemStateModel state;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Power allocation',
      child: Column(
        children: [
          SectionRow(
            label: 'Power budget',
            value: Formatters.power(state.availablePowerW),
          ),
          SectionRow(
            label: 'Active load power',
            value: Formatters.power(state.estimatedTotalLoadPowerW),
          ),
          SectionRow(
            label: 'Remaining power',
            value: Formatters.power(state.remainingPowerW),
          ),
          const Divider(),
          SectionRow(
            label: 'Fixed load power',
            value: Formatters.power(state.fixedLoadPowerW),
          ),
          SectionRow(
            label: 'Automatic load power',
            value: Formatters.power(state.autoLoadPowerW),
          ),
        ],
      ),
    );
  }
}
