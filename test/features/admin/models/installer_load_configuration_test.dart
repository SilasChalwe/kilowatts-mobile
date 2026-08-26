import 'package:flutter_test/flutter_test.dart';
import 'package:kilowatts_mobile/features/admin/models/installer_node_model.dart';
import 'package:kilowatts_mobile/features/loads/models/load_model.dart';

void main() {
  test('CONFIGURE_LOAD payload matches current firmware requirements', () {
    const configuration = InstallerLoadConfiguration(
      nodeMac: 'AA:BB:CC:DD:EE:FF',
      name: 'Pump',
      relayPin: 16,
      relayActiveHigh: false,
      nominalVoltageVolts: 12,
      nominalCurrentAmps: 2.5,
      branchMaximumCurrentAmps: 10,
      startupWatts: 45,
      priority: 8,
      mode: LoadMode.auto,
      powerType: InstallerLoadPowerType.dc,
      schedule: LoadSchedule(
        enabled: true,
        startHour: 6,
        startMinute: 0,
        endHour: 8,
        endMinute: 0,
      ),
    );

    expect(configuration.toCommandPayload(), {
      'nodeMac': 'AA:BB:CC:DD:EE:FF',
      'load': {
        'name': 'Pump',
        'relayPin': 16,
        'relayActiveHigh': false,
        'mode': 'AUTO_OFF',
        'powerType': 'DC',
        'priority': 8,
        'powerRatingWatts': 30.0,
        'schedule': {
          'enabled': true,
          'startHour': 6,
          'startMinute': 0,
          'endHour': 8,
          'endMinute': 0,
        },
      },
    });
  });

  test('AC load publishes AC power type', () {
    const configuration = InstallerLoadConfiguration(
      nodeMac: 'AA:BB:CC:DD:EE:FF',
      name: 'Lamp',
      relayPin: 17,
      relayActiveHigh: true,
      nominalVoltageVolts: 230,
      nominalCurrentAmps: 0.2,
      branchMaximumCurrentAmps: 5,
      startupWatts: 46,
      priority: 4,
      mode: LoadMode.fixed,
      powerType: InstallerLoadPowerType.ac,
    );

    final load = configuration.toCommandPayload()['load'] as Map<String, dynamic>;
    expect(load['powerType'], 'AC');
    expect(load['powerRatingWatts'], 46.0);
    expect(load['schedule'], {'enabled': false});
  });
}
