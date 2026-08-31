import 'package:flutter_test/flutter_test.dart';
import 'package:kilowatts_mobile/features/system/models/node_model.dart';
import 'package:kilowatts_mobile/features/system/models/topology_model.dart';

Map<String, dynamic> _load({required String nodeMac, required int relayPin}) {
  return {
    'name': 'Load $relayPin',
    'nodeName': 'Node',
    'nodeMac': nodeMac,
    'relayPin': relayPin,
    'controlMode': 'AUTOMATIC',
    'mode': 'AUTO_ON',
    'manualControlAllowed': false,
    'priority': 5,
    'powerRatingWatts': 5.0,
    'powerType': 'DC',
    'schedule': {'enabled': false},
    'bestFirstRejectionReason': 'NONE',
  };
}

/// Matches `TopologyTree::buildTreeJson`/`appendLoadsForNode`'s exact
/// recursive shape (see lib/NodeManager/Central/TopologyTree.cpp) — a
/// `{"central":{...}}` tree with nested `children`, and a flat `"loads"`
/// array (the same Load shape `state/loads` publishes) at every node.
/// Firmware never emits a `"branches"` key.
const _centralMac = 'AA:AA:AA:AA:AA:AA';
const _smartMac = 'BB:BB:BB:BB:BB:BB';
const _grandchildMac = 'CC:CC:CC:CC:CC:CC';

Map<String, dynamic> _tree() {
  return {
    'schemaVersion': 3,
    'central': {
      'type': 'central',
      'name': 'Central',
      'mac': _centralMac,
      'online': true,
      'loads': [_load(nodeMac: _centralMac, relayPin: 25)],
      'children': [
        {
          'type': 'smartNode',
          'name': 'Smart A',
          'mac': _smartMac,
          'parentMac': _centralMac,
          'hopCountToCentral': 1,
          'online': true,
          'loads': [_load(nodeMac: _smartMac, relayPin: 4)],
          'children': [
            {
              'type': 'smartNode',
              'name': 'Smart B',
              'mac': _grandchildMac,
              'parentMac': _smartMac,
              'hopCountToCentral': 2,
              'online': false,
              'loads': [_load(nodeMac: _grandchildMac, relayPin: 12)],
              'children': [],
            },
          ],
        },
      ],
    },
  };
}

void main() {
  group('TopologyModel.fromJson', () {
    test('walks a multi-level recursive tree and flattens the node list', () {
      final topology = TopologyModel.fromJson(_tree());
      expect(topology.nodes, hasLength(3));
    });

    test('identifies the central node by tree position, not a wire field', () {
      final topology = TopologyModel.fromJson(_tree());
      expect(topology.central?.mac, _centralMac);
      expect(topology.central?.role, NodeRole.central);
    });

    test('preserves communication hierarchy (parentMac/hopCount) across hops', () {
      final topology = TopologyModel.fromJson(_tree());
      final grandchild = topology.nodeByMac(_grandchildMac);

      expect(grandchild, isNotNull);
      expect(grandchild!.nextHopMac, _smartMac);
      expect(grandchild.hopCount, 2);
      expect(grandchild.online, isFalse);
      expect(topology.childrenOf(_centralMac).map((n) => n.mac), [_smartMac]);
      expect(topology.childrenOf(_smartMac).map((n) => n.mac), [_grandchildMac]);
    });

    test('each node carries its own loads, parsed from that node\'s "loads" array', () {
      final topology = TopologyModel.fromJson(_tree());

      expect(topology.nodeByMac(_smartMac)!.loads.single.relayPin, 4);
      expect(topology.nodeByMac(_grandchildMac)!.loads.single.relayPin, 12);
      expect(topology.central!.loads.single.relayPin, 25);
    });

    test('a null central (no Central registered yet) yields TopologyModel.empty', () {
      final topology = TopologyModel.fromJson({'schemaVersion': 3, 'central': null});
      expect(topology.nodes, isEmpty);
      expect(topology.central, isNull);
    });
  });
}
