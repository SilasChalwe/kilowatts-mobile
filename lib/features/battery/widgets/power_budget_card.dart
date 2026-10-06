import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/section_card.dart';
import '../../system/models/system_state_model.dart';

class PowerBudgetCard extends StatelessWidget {
  const PowerBudgetCard({required this.state, this.isLive = true, super.key});

  final SystemStateModel state;
  final bool isLive;

  @override
  Widget build(BuildContext context) {
    // Same order as the dissertation's own equation chain: budget and
    // reserve are the configured inputs (also editable on the Power plan
    // card); everything below is what Central derives from them each cycle.
    return SectionCard(
      title: 'Power allocation',
      child: Column(
        children: [
          SectionRow(label: 'Budget', value: Formatters.power(isLive ? state.powerBudgetWatts : null)),
          SectionRow(label: 'Reserve', value: Formatters.power(isLive ? state.powerReserveWatts : null)),
          const Divider(),
          SectionRow(
            label: 'Fixed load power',
            value: Formatters.power(isLive ? state.fixedLoadPowerW : null),
          ),
          SectionRow(
            label: 'Available power passed to Best-First',
            value: Formatters.power(isLive ? state.availablePowerW : null),
          ),
          SectionRow(
            label: 'Automatic load power',
            value: Formatters.power(isLive ? state.autoLoadPowerW : null),
          ),
          SectionRow(
            label: 'Remaining power',
            value: Formatters.power(isLive ? state.remainingPowerW : null),
          ),
          const Divider(),
          SectionRow(
            label: 'Active load power (fixed + auto)',
            value: Formatters.power(
              isLive ? state.estimatedTotalLoadPowerW : null,
            ),
          ),
        ],
      ),
    );
  }
}
