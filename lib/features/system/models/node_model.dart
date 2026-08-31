import '../../../core/utils/json_parsing.dart';
import '../../loads/models/load_model.dart';
import 'node_diagnostics_model.dart';

enum NodeRole {
  central,
  smartNode;

  static NodeRole fromWire(String? value) {
    return value == 'central' ? NodeRole.central : NodeRole.smartNode;
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

  /// Not currently published by firmware — `state/tree` has no per-node
  /// last-seen timestamp field, only the derived `online` boolean.
  final DateTime? lastSeen;

  /// Loads physically wired to this node's relays, parsed from this node's
  /// own `loads` array in `state/tree` (the same Load shape `state/loads`
  /// publishes flat, system-wide).
  final List<LoadModel> loads;

  /// Communication children (ESP-NOW downstream hops) — distinct from
  /// electrical branches. A multi-hop Smart Node can relay for another
  /// Smart Node without owning any of its loads.
  final List<String> childNodeMacs;

  final NodeDiagnosticsModel diagnostics;

  /// Always false today — firmware's `state/tree` has no "configured yet"
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

  /// Parses one node object from the recursive `state/tree` payload
  /// (`TopologyTree::appendLoadsForNode`/`buildTreeJson`'s `central`
  /// object). [isCentral] is supplied by the caller walking the tree, since
  /// the wire shape encodes role by position/`type`, not a flat field this
  /// model can read in isolation.
  factory NodeModel.fromJson(
    Map<String, dynamic> json, {
    required bool isCentral,
  }) {
    final loadsJson = json.listOfMaps('loads');
    final childrenJson = json.listOfMaps('children');
    final diagnosticsJson = json['diagnostics'];
    return NodeModel(
      mac: json.stringOrNull('mac') ?? '',
      role: isCentral ? NodeRole.central : NodeRole.smartNode,
      name: json.stringOrNull('name'),
      online: json.boolOrNull('online') ?? false,
      hopCount: json.intOrNull('hopCountToCentral'),
      nextHopMac: json.stringOrNull('parentMac'),
      loads: loadsJson.map(LoadModel.fromJson).toList(),
      childNodeMacs: [
        for (final child in childrenJson) child.stringOrNull('mac') ?? '',
      ],
      diagnostics: NodeDiagnosticsModel.fromJson(
        diagnosticsJson is Map<String, dynamic> ? diagnosticsJson : null,
      ),
    );
  }
}
