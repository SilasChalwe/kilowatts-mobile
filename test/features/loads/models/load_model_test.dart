import 'package:flutter_test/flutter_test.dart';
import 'package:kilowatts_mobile/features/loads/models/load_model.dart';

/// Exact current `TopologyTree::appendLoadJson` shape from the firmware.
Map<String, dynamic> _wireLoad({
  String mode = 'AUTO_ON',
  String rejectionReason = 'NONE',
}) {
  return {
    'name': 'Cooling Fan',
    'nodeName': 'Bedroom node',
    'nodeMac': 'AA:BB:CC:DD:EE:FF',
    'relayPin': 26,
    'controlMode': 'AUTO',
    'mode': mode,
    'manualControlAllowed': false,
    'priority': 7,
    'powerRatingWatts': 6.0,
    'powerType': 'DC',
    'schedule': {
      'enabled': true,
      'startHour': 22,
      'startMinute': 30,
      'endHour': 2,
      'endMinute': 15,
    },
    'bestFirstRejectionReason': rejectionReason,
  };
}

void main() {
  group('LoadModel.fromJson current firmware contract', () {
    test('parses identity, state, planning power and nested schedule', () {
      final load = LoadModel.fromJson(_wireLoad());

      expect(load.owningNodeMac, 'AA:BB:CC:DD:EE:FF');
      expect(load.owningNodeName, 'Bedroom node');
      expect(load.relayPin, 26);
      expect(load.name, 'Cooling Fan');
      expect(load.mode, LoadMode.auto);
      expect(load.priority, 7);
      expect(load.requestedState, true);
      expect(load.confirmedState, isNull);
      expect(load.confirmedStateValid, isFalse);
      expect(load.schedule.enabled, true);
      expect(load.schedule.startHour, 22);
      expect(load.schedule.startMinute, 30);
      expect(load.schedule.endHour, 2);
      expect(load.schedule.endMinute, 15);
      expect(load.ratedPowerW, 6.0);
      expect(load.id, 'AA:BB:CC:DD:EE:FF:26');
    });

    test('derives OFF state from current firmware mode when targetOn is absent', () {
      final load = LoadModel.fromJson(_wireLoad(mode: 'FIXED_OFF'));
      expect(load.mode, LoadMode.fixed);
      expect(load.requestedState, false);
      expect(load.displayState, false);
    });

    test('identity is node MAC plus relay pin', () {
      final a = LoadModel.fromJson(_wireLoad());
      final bJson = _wireLoad()..['nodeMac'] = '11:22:33:44:55:66';
      final b = LoadModel.fromJson(bJson);
      expect(a.relayPin, b.relayPin);
      expect(a.id == b.id, isFalse);
    });

    test('parses current Best-First rejection field', () {
      final load = LoadModel.fromJson(
        _wireLoad(rejectionReason: 'POWER_BUDGET_EXCEEDED'),
      );
      expect(
        load.rejectionReason,
        LoadRejectionReason.insufficientAvailablePower,
      );
    });

    test('NONE rejection reason is null', () {
      expect(LoadModel.fromJson(_wireLoad()).rejectionReason, isNull);
    });

    test('missing fields use safe defaults', () {
      final load = LoadModel.fromJson(const {});
      expect(load.owningNodeMac, '');
      expect(load.relayPin, -1);
      expect(load.confirmedStateValid, isFalse);
    });

    test('legacy payload remains readable during migration', () {
      final load = LoadModel.fromJson({
        'nodeMac': 'AA:BB:CC:DD:EE:FF',
        'relayPin': 16,
        'mode': 'AUTO_OFF',
        'targetOn': true,
        'scheduleEnabled': true,
        'scheduleHour': 6,
        'scheduleMinute': 30,
        'nominalPowerWatts': 8.0,
        'rejectionReason': 'LOW_BATTERY',
      });
      expect(load.requestedState, true);
      expect(load.schedule.startHour, 6);
      expect(load.schedule.startMinute, 30);
      expect(load.ratedPowerW, 8.0);
      expect(
        load.rejectionReason,
        LoadRejectionReason.batteryReserveProtected,
      );
    });
  });

  group('LoadSchedule firmware serialization', () {
    test('serializes enabled start/end window exactly', () {
      const schedule = LoadSchedule(
        enabled: true,
        startHour: 22,
        startMinute: 0,
        endHour: 2,
        endMinute: 0,
      );
      expect(schedule.toWireJson(), {
        'enabled': true,
        'startHour': 22,
        'startMinute': 0,
        'endHour': 2,
        'endMinute': 0,
      });
    });

    test('disabled schedule only needs enabled=false', () {
      expect(LoadSchedule.disabled.toWireJson(), {'enabled': false});
    });

    test('legacy single time becomes a valid one-hour window', () {
      const schedule = LoadSchedule(enabled: true, hour: 23, minute: 30);
      expect(schedule.toWireJson(), {
        'enabled': true,
        'startHour': 23,
        'startMinute': 30,
        'endHour': 0,
        'endMinute': 30,
      });
    });
  });

  group('LoadPriorityLevel', () {
    test('buckets raw 0-10 priority values', () {
      expect(LoadPriorityLevel.bucketFor(0), LoadPriorityLevel.low);
      expect(LoadPriorityLevel.bucketFor(3), LoadPriorityLevel.low);
      expect(LoadPriorityLevel.bucketFor(4), LoadPriorityLevel.medium);
      expect(LoadPriorityLevel.bucketFor(6), LoadPriorityLevel.medium);
      expect(LoadPriorityLevel.bucketFor(7), LoadPriorityLevel.high);
      expect(LoadPriorityLevel.bucketFor(10), LoadPriorityLevel.high);
    });
  });
}
