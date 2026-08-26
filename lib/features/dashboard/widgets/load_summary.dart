import 'package:flutter/material.dart';

import '../../../core/widgets/metric_card.dart';
import '../../../core/widgets/responsive_content.dart';
import '../../loads/models/load_model.dart';
import '../../system/models/topology_model.dart';

class LoadSummary extends StatelessWidget {
  const LoadSummary({required this.loads, required this.topology, super.key});

  final List<LoadModel> loads;
  final TopologyModel topology;

  @override
  Widget build(BuildContext context) {
    final activeLoads = loads.where((load) => load.displayState == true).length;
    final onlineNodes = topology.smartNodes.where((node) => node.online).length;

    return ResponsiveCardGrid(
      minCardWidth: 165,
      maxColumns: 2,
      children: [
        MetricCard(
          label: 'Loads on',
          value: '$activeLoads',
          icon: Icons.flash_on_outlined,
        ),
        MetricCard(
          label: 'Smart nodes online',
          value: '$onlineNodes/${topology.smartNodes.length}',
          icon: Icons.developer_board_outlined,
        ),
      ],
    );
  }
}
