import 'package:flutter_test/flutter_test.dart';
import 'package:kilowatts_mobile/features/loads/models/load_configuration.dart';
import 'package:kilowatts_mobile/features/loads/models/load_model.dart';

void main() {
  test('CONFIGURE_LOAD payload matches the firmware contract', () {
    const configuration = LoadConfiguration(
      nodeMac: 'AA:BB:CC:DD:EE:FF',
      name: 'Pump',
      relayPin: 16,
      relayActiveHigh: false,
      powerRatingWatts: 30,
      priority: 8,
      mode: LoadMode.auto,
      powerType: LoadPowerType.dc,
      schedule: LoadSchedule(
        enabled: true,
        startHour: 6,
        startMinute: 0,
        endHour: 8,
        endMinute: 0,
      ),
    );

    // Flat shape required by `MqttManager::handleLoadCommandMessage`'s
    // `action == "add"` branch — nodeMac/relayPin/name/power/priority/mode/
    // powerType/activeHigh/schedule are all top-level siblings, not nested
    // under a `load` object. `type`/`commandId`/`action` are added by
    // MqttService when it wraps this payload for publish.
    expect(configuration.toCommandPayload(), {
      'nodeMac': 'AA:BB:CC:DD:EE:FF',
      'relayPin': 16,
      'name': 'Pump',
      'power': 30.0,
      'priority': 8,
      'mode': 'AUTO_OFF',
      'powerType': 'DC',
      'activeHigh': false,
      'schedule': {
        'enabled': true,
        'startHour': 6,
        'startMinute': 0,
        'endHour': 8,
        'endMinute': 0,
      },
    });
  });

  test('AC load omits unused commissioning fields', () {
    const configuration = LoadConfiguration(
      nodeMac: 'AA:BB:CC:DD:EE:FF',
      name: 'Lamp',
      relayPin: 17,
      relayActiveHigh: true,
      powerRatingWatts: 46,
      priority: 4,
      mode: LoadMode.fixed,
      powerType: LoadPowerType.ac,
    );

    final payload = configuration.toCommandPayload();
    expect(payload['powerType'], 'AC');
    expect(payload['schedule'], {'enabled': false});
    expect(payload.containsKey('nominalVoltageVolts'), isFalse);
    expect(payload.containsKey('startupWatts'), isFalse);
  });
}
