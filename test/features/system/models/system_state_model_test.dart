import 'package:flutter_test/flutter_test.dart';
import 'package:kilowatts_mobile/features/system/models/system_state_model.dart';

/// Matches a real, live `state.system` payload captured directly from a
/// running Central node over MQTT (HiveMQ Cloud broker, TLS,
/// `kilowatts/v1/state`) — not inferred from documentation. `powerFlow` has
/// no validity flag on the wire; presence of `P_budget` is the signal a
/// plan has been configured. There is no `connectivity`, `time` or
/// `diagnostics` object at the system level — `lastOptimizationEpochSeconds`
/// is a top-level sibling of `battery`/`powerFlow`.
const _wirePayload = {
  'schemaVersion': 5,
  'battery': {
    'sensorConfigured': false,
    'nominalVoltageVolts': 15.0,
    'capacityAmpHours': 300.0,
    'ratedEnergyWattHours': 4500.0,
    'storedEnergyWattHours': 1533.942,
    'usableEnergyWattHours': 633.942,
    'voltageVolts': 13.0,
    'currentAmps': 9.231,
    'P_measured': 120.003,
    'measurementSource': 'SIMULATED',
    'stateOfChargePercent': 34.088,
    'stateOfChargeValid': true,
    'stateOfChargeSource': 'COULOMB_COUNTING',
    'batteryReserveReached': false,
    'requiredRuntimeConfigured': true,
    'requiredRuntimeHours': 4.0,
    'remainingRuntimeHours': 3.694,
    'estimatedRuntimeHours': 5.283,
    'runtimeEstimateValid': true,
    'requiredRuntimeAchievable': true,
  },
  'powerFlow': {
    'P_budget': 200.0,
    'P_reserve': 20.0,
    'P_fixed': 60.0,
    'P_auto_available': 111.645,
    'P_auto': 60.0,
    'P_remaining': 80.0,
  },
  'lastOptimizationEpochSeconds': 1788184231,
};

void main() {
  group('SystemStateModel.fromJson', () {
    test('reads fields from the current firmware wire shape', () {
      final state = SystemStateModel.fromJson(_wirePayload);

      expect(state.batteryVoltage, 13.0);
      expect(state.batteryCurrent, 9.231);
      expect(state.batterySocPercent, 34.088);
      expect(state.batterySensorConfigured, isFalse);
      expect(state.batteryCapacityAmpHours, 300.0);
      expect(state.batteryNominalVoltageV, 15.0);
      expect(state.stateOfChargeValid, isTrue);
      expect(state.stateOfChargeSource, 'COULOMB_COUNTING');
      expect(state.batteryReserveReached, isFalse);
      expect(state.requiredRuntimeConfigured, isTrue);
      expect(state.requiredRuntimeHours, 4.0);
      expect(state.remainingRuntimeHours, 3.694);
      expect(state.estimatedRuntimeHours, 5.283);
      expect(state.runtimeEstimateValid, isTrue);
      expect(state.requiredRuntimeAchievable, isTrue);
      expect(state.powerBudgetWatts, 200.0);
      expect(state.powerReserveWatts, 20.0);
      expect(state.estimatedTotalLoadPowerW, 120.0); // 60 W fixed + 60 W auto
      expect(state.sustainablePowerW, 111.645);
      expect(state.availablePowerW, 111.645);
      expect(state.fixedLoadPowerW, 60.0);
      expect(state.autoLoadPowerW, 60.0);
      expect(state.remainingPowerW, 80.0);
      expect(state.committedPowerW, 60.0);
      expect(state.sensorInputSource, 'SIMULATED');

      // Firmware does not currently publish these at the system level. They
      // must stay null rather than being fabricated by the client.
      expect(state.wifiConnected, isNull);
      expect(state.mqttConnected, isNull);
      expect(state.timeValid, isNull);
      expect(state.operatingEnvironment, isNull);
      expect(state.developmentSessionActive, isNull);
      expect(state.faultCount, isNull);
      expect(state.faultSummary, isNull);
    });

    test('derives batteryPowerW from voltage * current', () {
      final state = SystemStateModel.fromJson(_wirePayload);
      expect(state.batteryPowerW, closeTo(13.0 * 9.231, 0.0001));
    });

    test(
      'lastOptimizationEpochSeconds == 0 parses to null, not epoch 1970',
      () {
        final json = {..._wirePayload, 'lastOptimizationEpochSeconds': 0};
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
      'a missing P_budget nulls out every powerFlow-derived field, even '
      'though the raw JSON has other non-null-looking zeros',
      () {
        final json = {
          ..._wirePayload,
          'powerFlow': {
            'P_reserve': 0.0,
            'P_fixed': 0.0,
            'P_auto_available': 0.0,
            'P_auto': 0.0,
            'P_remaining': 0.0,
          },
        };
        final state = SystemStateModel.fromJson(json);

        expect(state.powerBudgetWatts, isNull);
        expect(state.powerReserveWatts, isNull);
        expect(state.estimatedTotalLoadPowerW, isNull);
        expect(state.sustainablePowerW, isNull);
        expect(state.availablePowerW, isNull);
        expect(state.fixedLoadPowerW, isNull);
        expect(state.autoLoadPowerW, isNull);
        expect(state.remainingPowerW, isNull);
        expect(state.committedPowerW, isNull);

        // battery.* fields are unaffected by powerFlow's own state.
        expect(state.batterySocPercent, 34.088);
      },
    );
  });
}
