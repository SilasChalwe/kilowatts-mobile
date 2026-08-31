import 'package:flutter_test/flutter_test.dart';
import 'package:kilowatts_mobile/core/models/telemetry_point.dart';
import 'package:kilowatts_mobile/core/services/telemetry_history_store.dart';

void main() {
  test('Firebase telemetry snapshot preserves every graph series', () {
    final first = DateTime.parse('2026-08-27T12:00:00Z');
    final second = DateTime.parse('2026-08-27T12:05:00Z');
    final history = TelemetryHistorySnapshot(
      soc: [
        TelemetryPoint(timestamp: first, value: 81),
        TelemetryPoint(timestamp: second, value: 80.4),
      ],
      batteryPower: [TelemetryPoint(timestamp: second, value: 96)],
      activeLoadPower: [TelemetryPoint(timestamp: second, value: 240)],
    );

    final restored = TelemetryHistorySnapshot.fromData(history.toData());

    expect(restored.soc, hasLength(2));
    expect(restored.soc.first.timestamp, first);
    expect(restored.soc.last.value, 80.4);
    expect(restored.batteryPower.single.value, 96);
    expect(restored.activeLoadPower.single.value, 240);
  });

  test('invalid Firebase points are ignored without inventing values', () {
    final restored = TelemetryHistorySnapshot.fromData({
      'soc': [
        {'timestamp': 'invalid', 'value': 75},
        {'timestamp': '2026-08-27T12:00:00Z', 'value': 75},
      ],
    });

    expect(restored.soc, hasLength(1));
    expect(restored.soc.single.value, 75);
    expect(restored.batteryPower, isEmpty);
    expect(restored.activeLoadPower, isEmpty);
  });
}
