import 'package:flutter_test/flutter_test.dart';
import 'package:kilowatts_mobile/features/admin/models/installer_node_model.dart';
import 'package:kilowatts_mobile/features/loads/models/load_model.dart';

void main() {
  test('normalizes current state/nodes lifecycle and capabilities', () {
    final node = InstallerNodeModel.fromJson(const {
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

  test('load configuration emits only fields required by CONFIGURE_LOAD', () {
    const configuration = InstallerLoadConfiguration(
      nodeMac: 'AA:BB:CC:DD:EE:FF',
      name: 'Kitchen fan',
      relayPin: 4,
      relayActiveHigh: false,
      nominalVoltageVolts: 12,
      nominalCurrentAmps: 1.5,
      branchMaximumCurrentAmps: 5,
      startupWatts: 24,
      priority: 7,
      mode: LoadMode.auto,
    );

    final payload = configuration.toCommandPayload();
    final load = (payload['load'] as Map).cast<String, dynamic>();

    expect(load['powerType'], 'DC');
    expect(load['powerRatingWatts'], 18.0);
    expect(load['priority'], 7);
    expect(load['mode'], 'AUTO_OFF');
    expect(load['schedule'], {'enabled': false});
    expect(load.containsKey('nominalVoltageVolts'), isFalse);
    expect(load.containsKey('nominalCurrentAmps'), isFalse);
    expect(load.containsKey('startupWatts'), isFalse);
    expect(load.containsKey('i2cAddress'), isFalse);
  });
}
