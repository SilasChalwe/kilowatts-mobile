import 'package:flutter_test/flutter_test.dart';
import 'package:kilowatts_mobile/features/system/models/system_state_model.dart';

/// Matches `SystemStateJson::build()`'s exact nested shape (see
/// lib/SystemStateJson/SystemStateJson.cpp) — not a flat snake_case object.
const _wirePayload = {
  'schemaVersion': 2,
  'battery': {
    'sensorConfigured': true,
    'voltageVolts': 12.6,
    'currentAmps': 8.0,
    'measurementSource': 'INA219 HARDWARE',
    'stateOfChargePercent': 76.5,
  },
  'power': {
    'estimatedTotalLoadPowerWatts': 40.0,
    'availablePowerWatts': 162.0,
    'fixedOnRunningPowerWatts': 12.0,
    'powerAvailableForAutoLoadsWatts': 150.0,
    'remainingPowerWatts': 97.0,
    'committedPowerWatts': 65.0,
  },
  'connectivity': {'wifiConnected': true, 'wifiState': 'CONNECTED', 'mqttConnected': true},
  'time': {'valid': true, 'source': 'NTP', 'lastOptimizationEpochSeconds': 1700000000},
  'diagnostics': {
    'operatingEnvironment': 'PRODUCTION',
    'developmentSessionActive': false,
    'faultCount': 0,
    'faultSummary': '',
  },
};

void main() {
  group('SystemStateModel.fromJson', () {
    test('reads every nested field from the real firmware wire shape', () {
      final state = SystemStateModel.fromJson(_wirePayload);

      expect(state.batteryVoltage, 12.6);
      expect(state.batteryCurrent, 8.0);
      expect(state.batterySocPercent, 76.5);
      expect(state.batterySensorConfigured, isTrue);
      expect(state.estimatedTotalLoadPowerW, 40.0);
      expect(state.availablePowerW, 162.0);
      expect(state.fixedLoadPowerW, 12.0);
      expect(state.autoLoadPowerW, 150.0);
      expect(state.remainingPowerW, 97.0);
      expect(state.committedPowerW, 65.0);
      expect(state.wifiConnected, true);
      expect(state.wifiState, 'CONNECTED');
      expect(state.mqttConnected, true);
      expect(state.timeValid, true);
      expect(state.timeSource, 'NTP');
      expect(state.sensorInputSource, 'INA219 HARDWARE');
      expect(state.faultCount, 0);
    });

    test('derives batteryPowerW from voltage * current', () {
      final state = SystemStateModel.fromJson(_wirePayload);
      expect(state.batteryPowerW, closeTo(12.6 * 8.0, 0.0001));
    });

    test('lastOptimizationEpochSeconds == 0 (no cycle run yet) parses to null, not epoch 1970', () {
      final json = {
        ..._wirePayload,
        'time': {'valid': false, 'source': 'NONE', 'lastOptimizationEpochSeconds': 0},
      };
      final state = SystemStateModel.fromJson(json);
      expect(state.lastOptimizationAt, isNull);
    });

    test('a real epoch value parses to a non-null DateTime', () {
      final state = SystemStateModel.fromJson(_wirePayload);
      expect(state.lastOptimizationAt, isNotNull);
    });

    test('missing nested objects fall back to all-null fields, never throw', () {
      final state = SystemStateModel.fromJson(const {'schemaVersion': 1});
      expect(state.batterySocPercent, isNull);
      expect(state.availablePowerW, isNull);
      expect(state.batteryPowerW, isNull);
    });
  });
}
