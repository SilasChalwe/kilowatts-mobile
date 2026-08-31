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
    return SectionCard(
      title: 'Power allocation',
      child: Column(
        children: [
          SectionRow(
            label: 'Available power passed to Best-First',
            value: Formatters.power(isLive ? state.availablePowerW : null),
          ),
          SectionRow(
            label: 'Active load power',
            value: Formatters.power(
              isLive ? state.estimatedTotalLoadPowerW : null,
            ),
          ),
          SectionRow(
            label: 'Remaining power',
            value: Formatters.power(isLive ? state.remainingPowerW : null),
          ),
          const Divider(),
          SectionRow(
            label: 'Fixed load power',
            value: Formatters.power(isLive ? state.fixedLoadPowerW : null),
          ),
          SectionRow(
            label: 'Automatic load power',
            value: Formatters.power(isLive ? state.autoLoadPowerW : null),
          ),
        ],
      ),
    );
  }
}
