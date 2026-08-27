import 'package:flutter_test/flutter_test.dart';
import 'package:kilowatts_mobile/core/models/telemetry_point.dart';
import 'package:kilowatts_mobile/core/services/local_state_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('SoC history survives local storage round trip', () async {
    final service = LocalStateService();
    final points = [
      TelemetryPoint(
        timestamp: DateTime.parse('2026-08-27T12:00:00Z'),
        value: 81.0,
      ),
      TelemetryPoint(
        timestamp: DateTime.parse('2026-08-27T12:01:00Z'),
        value: 80.4,
      ),
    ];

    await service.cacheSocHistory(points);
    final restored = await service.readSocHistory();

    expect(restored, hasLength(2));
    expect(restored.first.timestamp, points.first.timestamp);
    expect(restored.first.value, 81.0);
    expect(restored.last.timestamp, points.last.timestamp);
    expect(restored.last.value, 80.4);
  });

  test('Each telemetry series uses independent storage', () async {
    final service = LocalStateService();
    final timestamp = DateTime.parse('2026-08-27T12:00:00Z');

    await service.cacheBatteryPowerHistory([
      TelemetryPoint(timestamp: timestamp, value: 96.0),
    ]);
    await service.cacheActiveLoadPowerHistory([
      TelemetryPoint(timestamp: timestamp, value: 240.0),
    ]);

    expect((await service.readBatteryPowerHistory()).single.value, 96.0);
    expect((await service.readActiveLoadPowerHistory()).single.value, 240.0);
    expect(await service.readSocHistory(), isEmpty);
  });
}
