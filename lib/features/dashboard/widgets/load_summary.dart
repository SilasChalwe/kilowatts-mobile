import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/metric_card.dart';
import '../../loads/models/load_model.dart';
import '../../system/models/topology_model.dart';

class LoadSummary extends StatelessWidget {
  const LoadSummary({required this.loads, required this.topology, super.key});

  final List<LoadModel> loads;
  final TopologyModel topology;

  @override
  Widget build(BuildContext context) {
    final activeLoads = loads.where((l) => l.displayState == true).length;
    final onlineNodes = topology.smartNodes.where((n) => n.online).length;

    return Row(
      children: [
        Expanded(
          child: MetricCard(
            label: 'Loads On',
            value: '$activeLoads',
            icon: Icons.flash_on_outlined,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: MetricCard(
            label: 'Nodes Online',
            value: '$onlineNodes/${topology.smartNodes.length}',
            icon: Icons.developer_board_outlined,
          ),
        ),
      ],
    );
  }
}
