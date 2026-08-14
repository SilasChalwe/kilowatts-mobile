import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../loads/models/load_model.dart';
import '../models/node_model.dart';
import '../models/topology_model.dart';
import 'branch_card.dart';
import 'node_card.dart';

/// Renders Central → Smart Node communication hops as an indented,
/// expandable tree, with each node's electrically-owned branches/loads
/// listed as leaves underneath it. Communication depth and electrical
/// ownership are two different relationships and are never conflated here.
class TopologyTree extends StatelessWidget {
  const TopologyTree({
    required this.topology,
    required this.loads,
    super.key,
    this.onNodeTap,
    this.onLoadTap,
  });

  final TopologyModel topology;
  final List<LoadModel> loads;
  final ValueChanged<NodeModel>? onNodeTap;
  final ValueChanged<LoadModel>? onLoadTap;

  LoadModel? _loadFor(String nodeMac, int relayPin) {
    for (final load in loads) {
      if (load.owningNodeMac == nodeMac && load.relayPin == relayPin)
        return load;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final central = topology.central;
    if (central == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _buildSubtree(central, depth: 0),
    );
  }

  List<Widget> _buildSubtree(NodeModel node, {required int depth}) {
    final widgets = <Widget>[
      Padding(
        padding: EdgeInsets.only(left: depth * 20.0, bottom: AppSpacing.xs),
        child: NodeCard(
          node: node,
          onTap: onNodeTap == null ? null : () => onNodeTap!(node),
        ),
      ),
    ];

    for (final branch in topology.branchesOf(node.mac)) {
      final load = _loadFor(branch.owningNodeMac, branch.relayPin);
      widgets.add(
        Padding(
          padding: EdgeInsets.only(
            left: depth * 20.0 + 32,
            bottom: AppSpacing.xxs,
          ),
          child: BranchCard(
            branch: branch,
            loadName: load?.name,
            onTap: load == null || onLoadTap == null
                ? null
                : () => onLoadTap!(load),
          ),
        ),
      );
    }

    for (final child in topology.childrenOf(node.mac)) {
      widgets.addAll(_buildSubtree(child, depth: depth + 1));
    }

    return widgets;
  }
}
