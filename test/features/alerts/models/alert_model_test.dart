import 'package:flutter_test/flutter_test.dart';
import 'package:kilowatts_mobile/features/alerts/models/alert_model.dart';

void main() {
  group('AlertModel user-facing protection messages', () {
    test('translates LOW_BATTERY machine reason into a useful explanation', () {
      final alert = AlertModel.fromJson({
        'eventType': 'SYSTEM_PROTECTION',
        'title': 'Power is not safe',
        'detail': 'LOW_BATTERY',
        'timestampEpochSeconds': 1,
      });

      expect(alert.category, AlertCategory.lowBattery);
      expect(alert.title, 'Battery reserve too low');
      expect(alert.message, isNot(contains('LOW_BATTERY')));
      expect(alert.message, contains('safe reserve'));
    });

    test('translates current-limit reason codes', () {
      final alert = AlertModel.fromJson({
        'eventType': 'SYSTEM_PROTECTION',
        'detail': 'BATTERY_CURRENT_LIMIT',
        'timestampEpochSeconds': 1,
      });

      expect(alert.category, AlertCategory.batteryCurrentLimit);
      expect(alert.title, 'Battery current limit reached');
      expect(alert.message, contains('discharge current'));
    });

    test('keeps useful free-text firmware messages', () {
      final alert = AlertModel.fromJson({
        'eventType': 'NODE_OFFLINE',
        'message': 'Kitchen node has not reported for 45 seconds.',
        'timestampEpochSeconds': 1,
      });

      expect(alert.message, 'Kitchen node has not reported for 45 seconds.');
    });
  });
}
