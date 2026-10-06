import 'package:flutter_test/flutter_test.dart';
import 'package:kilowatts_mobile/core/models/telemetry_point.dart';

void main() {
  test('TelemetryPoint serializes timestamp and value', () {
    final timestamp = DateTime.parse('2026-08-27T12:30:00Z');
    final point = TelemetryPoint(timestamp: timestamp, value: 42.5);

    final restored = TelemetryPoint.fromJson(point.toJson());

    expect(restored.timestamp, timestamp);
    expect(restored.value, 42.5);
  });

  test('TelemetryPoint rejects malformed data', () {
    expect(
      () => TelemetryPoint.fromJson({'timestamp': 'bad', 'value': '42'}),
      throwsFormatException,
    );
  });
}
