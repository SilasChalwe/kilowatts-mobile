import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/section_card.dart';
import '../../system/models/system_state_model.dart';

class SocIndicator extends StatelessWidget {
  const SocIndicator({required this.state, this.isLive = true, super.key});

  final SystemStateModel state;
  final bool isLive;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Battery measurements',
      child: Column(
        children: [
          SectionRow(
            label: 'State of charge',
            value: Formatters.percent(isLive ? state.batterySocPercent : null),
          ),
          SectionRow(
            label: 'Source',
            value: (isLive ? state.sensorInputSource : null) ?? 'Unavailable',
          ),
          const Divider(),
          SectionRow(
            label: 'Battery voltage',
            value: Formatters.voltage(isLive ? state.batteryVoltage : null),
          ),
          SectionRow(
            label: 'Battery current',
            value: Formatters.current(isLive ? state.batteryCurrent : null),
          ),
          SectionRow(
            label: 'Instantaneous power',
            value: Formatters.power(isLive ? state.batteryPowerW : null),
          ),
        ],
      ),
    );
  }
}
