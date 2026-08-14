import 'package:flutter_test/flutter_test.dart';
import 'package:kilowatts_mobile/features/admin/models/installer_node_model.dart';
import 'package:kilowatts_mobile/features/loads/models/load_model.dart';

void main() {
  test('normalizes firmware lifecycle text for installer actions', () {
    final node = InstallerNodeModel.fromJson(const {
      'mac': 'AA:BB:CC:DD:EE:FF',
      'role': 'smart',
      'lifecycleState': 'commissioned',
      'syncState': 'SYNCED',
      'relayCapabilities': [4, 5],
    });

    expect(node.role, 'SMART');
    expect(node.lifecycleState, 'COMMISSIONED');
    expect(node.isSmartNode, isTrue);
    expect(node.isCommissioned, isTrue);
    expect(node.availableRelayPins, [4, 5]);
  });

  test('load configuration sends ratings, never a per-load INA219 setup', () {
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

    expect(load['nominalVoltageVolts'], 12);
    expect(load['nominalCurrentAmps'], 1.5);
    expect(load['branchMaximumCurrentAmps'], 5);
    expect(load['startupWatts'], 24);
    expect(load.containsKey('i2cAddress'), isFalse);
    expect(load.containsKey('shuntResistanceOhms'), isFalse);
    expect(load.containsKey('runningWatts'), isFalse);
  });
}
