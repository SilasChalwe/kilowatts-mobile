import 'package:flutter_test/flutter_test.dart';
import 'package:kilowatts_mobile/features/system/models/system_state_model.dart';

/// Matches the current firmware `SystemStateJson::build()` payload exactly.
const _wirePayload = {
  'schemaVersion': 2,
  'battery': {
    'sensorConfigured': true,
    'nominalVoltageVolts': 12.0,
    'capacityAmpHours': 100.0,
    'ratedEnergyWattHours': 1200.0,
    'storedEnergyWattHours': 918.0,
    'usableEnergyWattHours': 678.0,
    'voltageVolts': 12.6,
    'currentAmps': 8.0,
    'currentBatteryOutputPowerWatts': 100.8,
    'measurementSource': 'HARDWARE',
    'stateOfChargePercent': 76.5,
    'stateOfChargeValid': true,
    'stateOfChargeSource': 'COULOMB_COUNTING',
    'batteryReserveReached': false,
    'requiredRuntimeConfigured': true,
    'requiredRuntimeHours': 4.0,
    'remainingRuntimeHours': 3.4,
    'estimatedRuntimeHours': 5.1,
    'runtimeEstimateValid': true,
    'maximumPowerForRequiredRuntimeWatts': 169.5,
    'requiredRuntimeAchievable': true,
  },
  'powerFlow': {
    'powerFlowValid': true,
    'batteryMaximumPowerWatts': 180.0,
    'mainMaximumPowerWatts': 200.0,
    'fixedOnPowerWatts': 12.0,
    'automaticPowerBudgetWatts': 150.0,
    'selectedAutoLoadPowerWatts': 65.0,
    'remainingAutomaticBudgetWatts': 85.0,
  },
  'connectivity': {
    'wifiConnected': true,
    'wifiState': 'CONNECTED',
    'mqttConnected': true,
  },
  'time': {
    'valid': true,
    'source': 'NTP',
    'lastOptimizationEpochSeconds': 1700000000,
  },
  'diagnostics': {'pinCommandErrorCount': 0},
};

void main() {
  group('SystemStateModel.fromJson', () {
    test('reads fields from the current firmware wire shape', () {
      final state = SystemStateModel.fromJson(_wirePayload);

      expect(state.batteryVoltage, 12.6);
      expect(state.batteryCurrent, 8.0);
      expect(state.batterySocPercent, 76.5);
      expect(state.batterySensorConfigured, isTrue);
      expect(state.batteryCapacityAmpHours, 100.0);
      expect(state.batteryNominalVoltageV, 12.0);
      expect(state.requiredRuntimeConfigured, isTrue);
      expect(state.requiredRuntimeHours, 4.0);
      expect(state.estimatedTotalLoadPowerW, 77.0); // 12 W fixed + 65 W auto
      expect(state.availablePowerW, 150.0);
      expect(state.fixedLoadPowerW, 12.0);
      expect(state.autoLoadPowerW, 65.0);
      expect(state.remainingPowerW, 85.0);
      expect(state.committedPowerW, 12.0);
      expect(state.wifiConnected, true);
      expect(state.wifiState, 'CONNECTED');
      expect(state.mqttConnected, true);
      expect(state.timeValid, true);
      expect(state.timeSource, 'NTP');
      expect(state.sensorInputSource, 'HARDWARE');
      expect(state.faultCount, 0);

      // The firmware does not currently publish these fields. They must stay
      // null rather than being fabricated by the client.
      expect(state.operatingEnvironment, isNull);
      expect(state.developmentSessionActive, isNull);
      expect(state.faultSummary, isNull);
    });

    test('derives batteryPowerW from voltage * current', () {
      final state = SystemStateModel.fromJson(_wirePayload);
      expect(state.batteryPowerW, closeTo(12.6 * 8.0, 0.0001));
    });

    test(
      'lastOptimizationEpochSeconds == 0 parses to null, not epoch 1970',
      () {
        final json = {
          ..._wirePayload,
          'time': {
            'valid': false,
            'source': 'NONE',
            'lastOptimizationEpochSeconds': 0,
          },
        };
        final state = SystemStateModel.fromJson(json);
        expect(state.lastOptimizationAt, isNull);
      },
    );

    test('a real epoch value parses to a non-null DateTime', () {
      final state = SystemStateModel.fromJson(_wirePayload);
      expect(state.lastOptimizationAt, isNotNull);
    });

    test('missing nested objects produce all-null fields without throwing', () {
      final state = SystemStateModel.fromJson(const {'schemaVersion': 1});
      expect(state.batterySocPercent, isNull);
      expect(state.availablePowerW, isNull);
      expect(state.batteryPowerW, isNull);
    });

    test(
      'powerFlowValid: false nulls out every powerFlow-derived field, even though the raw JSON has non-null-looking zeros',
      () {
        final json = {
          ..._wirePayload,
          'powerFlow': {
            'powerFlowValid': false,
            'batteryMaximumPowerWatts': 0.0,
            'mainMaximumPowerWatts': 0.0,
            'fixedOnPowerWatts': 0.0,
            'automaticPowerBudgetWatts': 0.0,
            'selectedAutoLoadPowerWatts': 0.0,
            'remainingAutomaticBudgetWatts': 0.0,
          },
        };
        final state = SystemStateModel.fromJson(json);

        expect(state.estimatedTotalLoadPowerW, isNull);
        expect(state.availablePowerW, isNull);
        expect(state.fixedLoadPowerW, isNull);
        expect(state.autoLoadPowerW, isNull);
        expect(state.remainingPowerW, isNull);
        expect(state.committedPowerW, isNull);

        // battery.* fields are unaffected by powerFlowValid.
        expect(state.batterySocPercent, 76.5);
      },
    );
  });
}
