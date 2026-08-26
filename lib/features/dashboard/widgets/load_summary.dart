import 'package:flutter/material.dart';

import '../../../core/widgets/metric_card.dart';
import '../../../core/widgets/responsive_content.dart';
import '../../loads/models/load_model.dart';
import '../../system/models/topology_model.dart';

/// Count-only load summary. Power values are intentionally kept in
/// [PowerSummary] so the dashboard does not duplicate the same concept under
/// multiple cards.
class LoadSummary extends StatelessWidget {
  const LoadSummary({required this.loads, required this.topology, super.key});

  final List<LoadModel> loads;
  final TopologyModel topology;

  @override
  Widget build(BuildContext context) {
    final activeLoads = loads.where((load) => load.displayState == true).length;
    final fixedLoads = loads.where((load) => load.mode == LoadMode.fixed).length;
    final automaticLoads = loads.where((load) => load.mode == LoadMode.auto).length;

    return ResponsiveCardGrid(
      minCardWidth: 165,
      maxColumns: 3,
      children: [
        MetricCard(
          label: 'Loads on',
          value: '$activeLoads',
          icon: Icons.flash_on_outlined,
        ),
        MetricCard(
          label: 'Fixed loads',
          value: '$fixedLoads',
          icon: Icons.push_pin_outlined,
        ),
        MetricCard(
          label: 'Automatic loads',
          value: '$automaticLoads',
          icon: Icons.auto_mode_outlined,
        ),
      ],
    );
  }
}
