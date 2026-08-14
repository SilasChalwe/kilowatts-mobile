import 'package:flutter_test/flutter_test.dart';
import 'package:kilowatts_mobile/features/loads/models/load_model.dart';

/// Matches `TopologyTree::appendLoadJson`'s exact wire shape (see
/// lib/TopologyTree/TopologyTree.cpp) — camelCase, flat, with
/// `confirmedStateValid` (not `confirmedRelayStateValid`).
Map<String, dynamic> _wireLoad({
  String mode = 'AUTO_ON',
  bool targetOn = true,
  bool confirmedOn = true,
  bool confirmedStateValid = true,
  String health = 'AVAILABLE',
  String rejectionReason = 'NONE',
}) {
  return {
    'relayPin': 26,
    'name': 'Cooling Fan',
    'nodeMac': 'AA:BB:CC:DD:EE:FF',
    'mode': mode,
    'targetOn': targetOn,
    'confirmedOn': confirmedOn,
    'confirmedStateValid': confirmedStateValid,
    'priority': 7,
    // Smart Nodes do not measure individual loads.  These are the
    // installer-entered electrical ratings emitted by `TopologyTree`.
    'nominalVoltageVolts': 12.0,
    'nominalCurrentAmps': 0.5,
    'nominalPowerWatts': 6.0,
    'startupWatts': 9.0,
    'perLoadMeasurementAvailable': false,
    'scheduleEnabled': true,
    'scheduleHour': 6,
    'scheduleMinute': 30,
    'health': health,
    'rejectionReason': rejectionReason,
  };
}

void main() {
  group('LoadModel.fromJson', () {
    test('parses every field from the real firmware wire shape', () {
      final load = LoadModel.fromJson(_wireLoad());

      expect(load.owningNodeMac, 'AA:BB:CC:DD:EE:FF');
      expect(load.relayPin, 26);
      expect(load.name, 'Cooling Fan');
      expect(load.mode, LoadMode.auto);
      expect(load.priority, 7);
      expect(load.requestedState, true);
      expect(load.confirmedState, true);
      expect(load.confirmedStateValid, true);
      expect(load.health, LoadHealth.available);
      expect(load.available, true);
      expect(load.schedule.enabled, true);
      expect(load.schedule.hour, 6);
      expect(load.schedule.minute, 30);
      expect(load.ratedVoltageV, 12.0);
      expect(load.ratedCurrentA, 0.5);
      expect(load.plannedPowerW, 6.0);
      expect(load.startupPowerW, 9.0);
      expect(load.id, 'AA:BB:CC:DD:EE:FF:26');
    });

    test('identity is nodeMac + relayPin, distinguishing the same pin on two different nodes', () {
      final a = LoadModel.fromJson(_wireLoad());
      final bJson = _wireLoad()..['nodeMac'] = '11:22:33:44:55:66';
      final b = LoadModel.fromJson(bJson);

      expect(a.relayPin, b.relayPin);
      expect(a.id == b.id, isFalse);
    });

    test('targetOn (the Best-First decision) is independent of mode', () {
      final load = LoadModel.fromJson(_wireLoad(mode: 'AUTO_OFF', targetOn: true));
      expect(load.mode, LoadMode.auto);
      expect(load.requestedState, true);
    });

    for (final wireMode in ['FIXED_ON', 'FIXED_OFF', 'AUTO_ON', 'AUTO_OFF']) {
      test('maps mode "$wireMode" to the correct LoadMode bucket', () {
        final load = LoadModel.fromJson(_wireLoad(mode: wireMode));
        final expected = wireMode.startsWith('FIXED') ? LoadMode.fixed : LoadMode.auto;
        expect(load.mode, expected);
      });
    }

    test('"NONE" rejection reason parses to null, not "unknown"', () {
      final load = LoadModel.fromJson(_wireLoad(rejectionReason: 'NONE'));
      expect(load.rejectionReason, isNull);
    });

    test('"LOW_BATTERY" (the most common real value) maps to batteryReserveProtected', () {
      final load = LoadModel.fromJson(_wireLoad(rejectionReason: 'LOW_BATTERY'));
      expect(load.rejectionReason, LoadRejectionReason.batteryReserveProtected);
      expect(load.rejectionReason!.friendlyText, 'Battery reserve protected');
    });

    test('every other documented rejection reason maps to a friendly, non-raw string', () {
      const cases = {
        'POWER_BUDGET_EXCEEDED': LoadRejectionReason.insufficientAvailablePower,
        'BATTERY_CURRENT_LIMIT': LoadRejectionReason.batteryCurrentLimitReached,
        'MAIN_LIMIT_EXCEEDED': LoadRejectionReason.mainDistributionLimitReached,
        'BRANCH_LIMIT_EXCEEDED': LoadRejectionReason.branchCurrentLimitReached,
      };
      for (final entry in cases.entries) {
        final load = LoadModel.fromJson(_wireLoad(rejectionReason: entry.key));
        expect(load.rejectionReason, entry.value, reason: entry.key);
      }
    });

    test('unrecognised rejection reason maps to unknown, not a crash', () {
      final load = LoadModel.fromJson(_wireLoad(rejectionReason: 'SOMETHING_NEW'));
      expect(load.rejectionReason, LoadRejectionReason.unknown);
    });

    test('health maps FAULTED/UNAVAILABLE correctly and drives `available`', () {
      expect(LoadModel.fromJson(_wireLoad(health: 'FAULTED')).available, isFalse);
      expect(LoadModel.fromJson(_wireLoad(health: 'UNAVAILABLE')).available, isFalse);
      expect(LoadModel.fromJson(_wireLoad(health: 'AVAILABLE')).available, isTrue);
    });

    test('missing/invalid fields fall back to safe defaults, never throw', () {
      final load = LoadModel.fromJson(const {});
      expect(load.owningNodeMac, '');
      expect(load.relayPin, -1);
      expect(load.confirmedStateValid, isFalse);
    });
  });

  group('LoadPriorityLevel', () {
    test('buckets the raw 0-10 wire priority', () {
      expect(LoadPriorityLevel.bucketFor(0), LoadPriorityLevel.low);
      expect(LoadPriorityLevel.bucketFor(3), LoadPriorityLevel.low);
      expect(LoadPriorityLevel.bucketFor(4), LoadPriorityLevel.medium);
      expect(LoadPriorityLevel.bucketFor(6), LoadPriorityLevel.medium);
      expect(LoadPriorityLevel.bucketFor(7), LoadPriorityLevel.high);
      expect(LoadPriorityLevel.bucketFor(10), LoadPriorityLevel.high);
    });
  });
}
