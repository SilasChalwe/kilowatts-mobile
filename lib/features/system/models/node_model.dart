import '../../../core/utils/json_parsing.dart';
import '../../loads/models/load_model.dart';
import 'node_diagnostics_model.dart';

enum NodeRole {
  central,
  smartNode;

  static NodeRole fromWire(String? value) {
    return value?.toLowerCase() == 'central'
        ? NodeRole.central
        : NodeRole.smartNode;
  }
}

/// A physical ESP32 device — either the Central Node or a Smart Node. Never
/// use a Node's MAC alone to identify a Load; see [LoadModel].
class NodeModel {
  const NodeModel({
    required this.mac,
    required this.role,
    this.name,
    this.online = false,
    this.rssi,
    this.hopCount,
    this.nextHopMac,
    this.lastSeen,
    this.loads = const [],
    this.childNodeMacs = const [],
    this.diagnostics = const NodeDiagnosticsModel(),
    this.isNewlyDiscovered = false,
  });

  final String mac;
  final NodeRole role;
  final String? name;
  final bool online;

  /// Not currently published by firmware (known locally by each Smart Node
  /// about its own upstream link, but never transmitted to Central) —
  /// always null until firmware's ESP-NOW wire protocol carries it.
  final int? rssi;
  final int? hopCount;
  final String? nextHopMac;

  /// Not currently published by firmware — `state.nodes` has no per-node
  /// last-seen timestamp field, only the derived `online` boolean.
  final DateTime? lastSeen;

  /// Loads physically wired to this node's relays. Firmware's `state.nodes`
  /// entries do not nest a `loads` array — this is cross-referenced by the
  /// caller from the separate flat `state.loads.loads[]` array by matching
  /// `nodeMac`, then passed in here (see [MqttService]).
  final List<LoadModel> loads;

  /// Communication children (ESP-NOW downstream hops) — distinct from
  /// electrical branches. Derived by the caller from other nodes whose
  /// `nextHopMac` equals this node's `mac`, since firmware publishes a flat
  /// node list, not a parent-referenced tree.
  final List<String> childNodeMacs;

  final NodeDiagnosticsModel diagnostics;

  /// Always false today — firmware's `state.nodes` has no "configured yet"
  /// flag to distinguish a freshly-discovered node from a named one.
  final bool isNewlyDiscovered;

  String get displayName {
    if (name != null && name!.trim().isNotEmpty) return name!;
    if (role == NodeRole.central) return 'Central Node';
    return 'Smart-${mac.length >= 4 ? mac.substring(mac.length - 4) : mac}';
  }

  NodeModel copyWith({String? name, bool? isNewlyDiscovered}) {
    return NodeModel(
      mac: mac,
      role: role,
      name: name ?? this.name,
      online: online,
      rssi: rssi,
      hopCount: hopCount,
      nextHopMac: nextHopMac,
      lastSeen: lastSeen,
      loads: loads,
      childNodeMacs: childNodeMacs,
      diagnostics: diagnostics,
      isNewlyDiscovered: isNewlyDiscovered ?? this.isNewlyDiscovered,
    );
  }

  /// Parses one entry of the real, flat `state.nodes.nodes[]` array
  /// (`SystemStateJson`/`TopologyTree` in the firmware repo), verified
  /// against a live broker capture. [loadsForThisNode] and
  /// [childNodeMacsForThisNode] are computed once by the caller across the
  /// whole node list (see [MqttService._routeState]) rather than here, since
  /// neither is available on a single node's own JSON object.
  factory NodeModel.fromJson(
    Map<String, dynamic> json, {
    List<LoadModel> loadsForThisNode = const [],
    List<String> childNodeMacsForThisNode = const [],
  }) {
    final diagnosticsJson = json['diagnostics'];
    final lifecycleState = (json.stringOrNull('lifecycleState') ?? '')
        .toUpperCase();
    return NodeModel(
      mac: json.stringOrNull('mac') ?? '',
      role: NodeRole.fromWire(json.stringOrNull('role')),
      name: json.stringOrNull('nodeName'),
      online: json.boolOrNull('online') ?? false,
      hopCount: json.intOrNull('hopCountToCentral'),
      nextHopMac: json.stringOrNull('nextHopMac'),
      loads: loadsForThisNode,
      childNodeMacs: childNodeMacsForThisNode,
      diagnostics: NodeDiagnosticsModel.fromJson(
        diagnosticsJson is Map<String, dynamic> ? diagnosticsJson : null,
        firmwareVersion: json.stringOrNull('firmwareVersion'),
        chipModel: json.stringOrNull('chipModel'),
      ),
      isNewlyDiscovered:
          lifecycleState == 'DISCOVERED' || lifecycleState == 'UNCOMMISSIONED',
    );
  }

  /// Builds every [NodeModel] from the real flat `state.nodes.nodes[]`
  /// array, cross-referencing each node's own loads from the separate flat
  /// `state.loads.loads[]` array (matched by `nodeMac`) and communication
  /// children from other nodes' `nextHopMac` — neither is available on a
  /// single node's own JSON object in isolation.
  static List<NodeModel> listFromState(
    List<Map<String, dynamic>> nodesJson,
    List<LoadModel> loads,
  ) {
    final nextHopByMac = <String, String>{};
    for (final nodeJson in nodesJson) {
      final mac = nodeJson.stringOrNull('mac');
      final nextHop = nodeJson.stringOrNull('nextHopMac');
      if (mac != null && nextHop != null) nextHopByMac[mac] = nextHop;
    }
    return nodesJson.map((nodeJson) {
      final mac = nodeJson.stringOrNull('mac') ?? '';
      return NodeModel.fromJson(
        nodeJson,
        loadsForThisNode: loads
            .where((l) => l.owningNodeMac == mac)
            .toList(growable: false),
        childNodeMacsForThisNode: [
          for (final entry in nextHopByMac.entries)
            if (entry.value == mac) entry.key,
        ],
      );
    }).toList(growable: false);
  }
}
