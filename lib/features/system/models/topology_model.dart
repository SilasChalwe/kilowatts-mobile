import 'node_model.dart';

/// Firmware publishes a single flat `state.nodes.nodes[]` array, not a
/// recursive tree — [MqttService] builds each [NodeModel] (cross-referencing
/// `state.loads.loads[]` by `nodeMac` for each node's own loads, and other
/// nodes' `nextHopMac` for communication children) and hands the resulting
/// flat list straight to this constructor. The getters below reconstruct the
/// hierarchy from that flat list on demand.
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
}
