import 'package:flutter_test/flutter_test.dart';
import 'package:kilowatts_mobile/features/system/models/system_node_model.dart';

void main() {
  test('normalizes current state/nodes lifecycle and capabilities', () {
    final node = SystemNodeModel.fromJson(const {
      'mac': 'AA:BB:CC:DD:EE:FF',
      'role': 'smart',
      'lifecycleState': 'commissioned',
      'syncState': 'SYNCED',
      'nodeName': 'Kitchen node',
      'availableRelayPins': [4, 5],
      'online': true,
    });

    expect(node.role, 'SMART');
    expect(node.lifecycleState, 'COMMISSIONED');
    expect(node.isSmartNode, isTrue);
    expect(node.isCommissioned, isTrue);
    expect(node.displayName, 'Kitchen node');
    expect(node.availableRelayPins, [4, 5]);
    expect(node.online, isTrue);
  });
}
