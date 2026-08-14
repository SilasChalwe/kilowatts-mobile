import '../../../core/utils/json_parsing.dart';
import 'branch_model.dart';
import 'node_model.dart';

/// Parsed payload of `kilowatts/v1/state/tree` — firmware publishes this as
/// a recursive `{"central":{"branches":[...],"children":[{...}]}}` tree
/// (`TopologyTree::buildTreeJson`), not a flat list. This model walks that
/// tree once at parse time and flattens it into `nodes`/`branches` so every
/// consumer keeps working with simple lookups.
///
/// Communication topology (ESP-NOW hops to Central) and electrical topology
/// (which branches a node owns) are kept as separate relationships; a
/// communication child is not necessarily an electrical child, and the tree
/// UI must not conflate the two.
class TopologyModel {
  const TopologyModel({this.nodes = const [], this.branches = const []});

  final List<NodeModel> nodes;
  final List<BranchModel> branches;

  static const empty = TopologyModel();

  NodeModel? get central {
    for (final node in nodes) {
      if (node.role == NodeRole.central) return node;
    }
    return null;
  }

  List<NodeModel> get smartNodes =>
      nodes.where((n) => n.role != NodeRole.central).toList();

  List<NodeModel> get newlyDiscoveredNodes =>
      smartNodes.where((n) => n.isNewlyDiscovered).toList();

  NodeModel? nodeByMac(String mac) {
    for (final node in nodes) {
      if (node.mac == mac) return node;
    }
    return null;
  }

  /// Direct communication children of [mac] (ESP-NOW hops), not electrical
  /// children.
  List<NodeModel> childrenOf(String mac) {
    return nodes.where((n) => n.nextHopMac == mac).toList();
  }

  List<BranchModel> branchesOf(String mac) {
    return branches.where((b) => b.owningNodeMac == mac).toList();
  }

  factory TopologyModel.fromJson(Map<String, dynamic> json) {
    final central = json.mapOrNull('central');
    if (central == null) return TopologyModel.empty;

    final nodes = <NodeModel>[];
    final branches = <BranchModel>[];

    void walk(Map<String, dynamic> nodeJson, {required bool isCentral}) {
      nodes.add(NodeModel.fromJson(nodeJson, isCentral: isCentral));
      for (final branchJson in nodeJson.listOfMaps('branches')) {
        branches.add(BranchModel.fromJson(branchJson));
      }
      for (final childJson in nodeJson.listOfMaps('children')) {
        walk(childJson, isCentral: false);
      }
    }

    walk(central, isCentral: true);
    return TopologyModel(nodes: nodes, branches: branches);
  }
}
