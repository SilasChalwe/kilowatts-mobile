import '../../../core/utils/json_parsing.dart';
import 'node_model.dart';

/// Parsed payload of `kilowatts/v1/state/tree` — firmware publishes this as
/// a recursive `{"central":{"loads":[...],"children":[{...}]}}` tree
/// (`TopologyTree::buildTreeJson`/`appendLoadsForNode`), not a flat list.
/// This model walks that tree once at parse time and flattens it into
/// `nodes` (each carrying its own `loads`) so every consumer keeps working
/// with simple lookups.
class TopologyModel {
  const TopologyModel({this.nodes = const []});

  final List<NodeModel> nodes;

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

  factory TopologyModel.fromJson(Map<String, dynamic> json) {
    final central = json.mapOrNull('central');
    if (central == null) return TopologyModel.empty;

    final nodes = <NodeModel>[];

    void walk(Map<String, dynamic> nodeJson, {required bool isCentral}) {
      nodes.add(NodeModel.fromJson(nodeJson, isCentral: isCentral));
      for (final childJson in nodeJson.listOfMaps('children')) {
        walk(childJson, isCentral: false);
      }
    }

    walk(central, isCentral: true);
    return TopologyModel(nodes: nodes);
  }
}
