import 'package:flutter_test/flutter_test.dart';
import 'package:kilowatts_mobile/features/system/models/node_model.dart';
import 'package:kilowatts_mobile/features/system/models/topology_model.dart';

Map<String, dynamic> _load({required String nodeMac, required int relayPin}) {
  return {
    'relayPin': relayPin,
    'name': 'Load $relayPin',
    'nodeMac': nodeMac,
    'mode': 'AUTO_ON',
    'targetOn': true,
    'confirmedOn': true,
    'confirmedStateValid': true,
    'priority': 5,
    'runningWatts': 5.0,
    'startupWatts': 5.0,
    'measuredVoltageVolts': 12.0,
    'measuredCurrentAmps': 0.4,
    'measuredPowerWatts': 4.8,
    'scheduleEnabled': false,
    'scheduleHour': 0,
    'scheduleMinute': 0,
    'health': 'AVAILABLE',
    'rejectionReason': 'NONE',
  };
}

Map<String, dynamic> _branch({required String nodeMac, required int relayPin}) {
  return {
    'type': 'branch',
    'nodeMac': nodeMac,
    'relayPin': relayPin,
    'maximumCurrentAmps': 10.0,
    'maximumCurrentConfigured': true,
    'load': _load(nodeMac: nodeMac, relayPin: relayPin),
  };
}

/// Matches `TopologyTree::buildTreeJson`'s exact recursive shape (see
/// lib/TopologyTree/TopologyTree.cpp) — a `{"central":{...}}` tree with
/// nested `children`, not a flat `{"nodes":[...],"branches":[...]}` list.
const _centralMac = 'AA:AA:AA:AA:AA:AA';
const _smartMac = 'BB:BB:BB:BB:BB:BB';
const _grandchildMac = 'CC:CC:CC:CC:CC:CC';

Map<String, dynamic> _tree() {
  return {
    'schemaVersion': 1,
    'central': {
      'type': 'central',
      'name': 'Central',
      'mac': _centralMac,
      'online': true,
      'branches': [_branch(nodeMac: _centralMac, relayPin: 25)],
      'children': [
        {
          'type': 'smartNode',
          'name': 'Smart A',
          'mac': _smartMac,
          'parentMac': _centralMac,
          'hopCountToCentral': 1,
          'online': true,
          'branches': [_branch(nodeMac: _smartMac, relayPin: 4)],
          'children': [
            {
              'type': 'smartNode',
              'name': 'Smart B',
              'mac': _grandchildMac,
              'parentMac': _smartMac,
              'hopCountToCentral': 2,
              'online': false,
              'branches': [_branch(nodeMac: _grandchildMac, relayPin: 12)],
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
    test('walks a multi-level recursive tree and flattens it', () {
      final topology = TopologyModel.fromJson(_tree());

      expect(topology.nodes, hasLength(3));
      expect(topology.branches, hasLength(3));
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

    test('branches carry electrical ownership independent of communication topology', () {
      final topology = TopologyModel.fromJson(_tree());
      expect(topology.branchesOf(_smartMac).single.relayPin, 4);
      expect(topology.branchesOf(_grandchildMac).single.relayPin, 12);
    });

    test('a null central (no Central registered yet) yields TopologyModel.empty', () {
      final topology = TopologyModel.fromJson({'schemaVersion': 1, 'central': null});
      expect(topology.nodes, isEmpty);
      expect(topology.central, isNull);
    });
  });
}
