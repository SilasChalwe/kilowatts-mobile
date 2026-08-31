import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/section_card.dart';
import '../../system/models/system_state_model.dart';

class SocIndicator extends StatelessWidget {
  const SocIndicator({required this.state, super.key});

  final SystemStateModel state;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Battery measurements',
      child: Column(
        children: [
          SectionRow(
            label: 'Battery voltage',
            value: Formatters.voltage(state.batteryVoltage),
          ),
          SectionRow(
            label: 'Battery current',
            value: Formatters.current(state.batteryCurrent),
          ),
          SectionRow(
            label: 'Instantaneous power',
            value: Formatters.power(state.batteryPowerW),
          ),
        ],
      ),
    );
  }
}
