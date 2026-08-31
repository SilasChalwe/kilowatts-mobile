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
      expect(load.schedule.enabled, true);
      expect(load.schedule.startHour, 22);
      expect(load.schedule.startMinute, 30);
      expect(load.schedule.endHour, 2);
      expect(load.schedule.endMinute, 15);
      expect(load.ratedPowerW, 6.0);
      expect(load.id, 'AA:BB:CC:DD:EE:FF:26');
    });

    test('derives OFF state from the current firmware mode', () {
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
