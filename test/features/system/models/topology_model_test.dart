import 'package:flutter_test/flutter_test.dart';
import 'package:kilowatts_mobile/features/loads/models/load_model.dart';
import 'package:kilowatts_mobile/features/system/models/node_model.dart';
import 'package:kilowatts_mobile/features/system/models/topology_model.dart';

/// Matches the real, flat `state.nodes.nodes[]` array (verified against a
/// live broker capture) — no recursive tree, no per-node `loads`/`children`.
/// Communication hierarchy is expressed by each node's own `nextHopMac`,
/// and a node's loads are a separate flat array (`state.loads.loads[]`)
/// cross-referenced by `nodeMac`.
const _centralMac = 'AA:AA:AA:AA:AA:AA';
const _smartMac = 'BB:BB:BB:BB:BB:BB';
const _grandchildMac = 'CC:CC:CC:CC:CC:CC';

Map<String, dynamic> _node({
  required String mac,
  required String role,
  required String name,
  bool? online,
  int? hopCountToCentral,
  String? nextHopMac,
}) {
  return {
    'mac': mac,
    'role': role,
    'nodeName': name,
    'lifecycleState': 'commissioned',
    'syncState': 'SYNCED',
    'online': online,
    'hopCountToCentral': hopCountToCentral,
    'nextHopMac': nextHopMac,
  };
}

Map<String, dynamic> _load({required String nodeMac, required int relayPin}) {
  return {
    'name': 'Load $relayPin',
    'nodeName': 'Node',
    'nodeMac': nodeMac,
    'relayPin': relayPin,
    'controlMode': 'AUTO',
    'mode': 'AUTO_ON',
    'priority': 5,
    'powerRatingWatts': 5.0,
    'powerType': 'DC',
    'schedule': {'enabled': false},
    'bestFirstRejectionReason': 'NONE',
  };
}

List<Map<String, dynamic>> _nodesJson() => [
  _node(mac: _centralMac, role: 'central', name: 'Central', online: null),
  _node(
    mac: _smartMac,
    role: 'smart',
    name: 'Smart A',
    online: true,
    hopCountToCentral: 1,
    nextHopMac: _centralMac,
  ),
  _node(
    mac: _grandchildMac,
    role: 'smart',
    name: 'Smart B',
    online: false,
    hopCountToCentral: 2,
    nextHopMac: _smartMac,
  ),
];

List<LoadModel> _loads() => [
  _load(nodeMac: _centralMac, relayPin: 25),
  _load(nodeMac: _smartMac, relayPin: 4),
  _load(nodeMac: _grandchildMac, relayPin: 12),
].map(LoadModel.fromJson).toList();

void main() {
  group('NodeModel.listFromState', () {
    test('builds one NodeModel per flat state.nodes entry', () {
      final topology = TopologyModel(
        nodes: NodeModel.listFromState(_nodesJson(), _loads()),
      );
      expect(topology.nodes, hasLength(3));
    });

    test('identifies the central node from its role field', () {
      final topology = TopologyModel(
        nodes: NodeModel.listFromState(_nodesJson(), _loads()),
      );
      expect(topology.central?.mac, _centralMac);
      expect(topology.central?.role, NodeRole.central);
    });

    test(
      'reconstructs communication hierarchy from nextHopMac across hops',
      () {
        final topology = TopologyModel(
          nodes: NodeModel.listFromState(_nodesJson(), _loads()),
        );
        final grandchild = topology.nodeByMac(_grandchildMac);

        expect(grandchild, isNotNull);
        expect(grandchild!.nextHopMac, _smartMac);
        expect(grandchild.hopCount, 2);
        expect(grandchild.online, isFalse);
        expect(topology.childrenOf(_centralMac).map((n) => n.mac), [_smartMac]);
        expect(topology.childrenOf(_smartMac).map((n) => n.mac), [
          _grandchildMac,
        ]);
      },
    );

    test(
      'cross-references each node\'s own loads from the flat loads array by nodeMac',
      () {
        final topology = TopologyModel(
          nodes: NodeModel.listFromState(_nodesJson(), _loads()),
        );

        expect(topology.nodeByMac(_smartMac)!.loads.single.relayPin, 4);
        expect(topology.nodeByMac(_grandchildMac)!.loads.single.relayPin, 12);
        expect(topology.central!.loads.single.relayPin, 25);
      },
    );

    test('an empty node list yields TopologyModel.empty-equivalent state', () {
      final topology = TopologyModel(
        nodes: NodeModel.listFromState(const [], const []),
      );
      expect(topology.nodes, isEmpty);
      expect(topology.central, isNull);
    });
  });
}
