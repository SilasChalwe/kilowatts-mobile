import 'package:flutter_test/flutter_test.dart';
import 'package:kilowatts_mobile/core/constants/app_constants.dart';
import 'package:kilowatts_mobile/core/services/command_outcome.dart';
import 'package:kilowatts_mobile/core/services/mqtt_service.dart';

void main() {
  group('MqttTopics', () {
    test('builds every topic under the configured namespace', () {
      const topics = MqttTopics('kilowatts/v1');

      expect(topics.status, 'kilowatts/v1/status');
      expect(topics.state, 'kilowatts/v1/state');
      expect(topics.command, 'kilowatts/v1/command');
      expect(topics.ack, 'kilowatts/v1/ack');
      expect(topics.alert, 'kilowatts/v1/alert');
    });

    test('subscriptions never include the publish-only command topic', () {
      const topics = MqttTopics('kilowatts/v1');

      expect(topics.subscriptions, isNot(contains(topics.command)));
      expect(
        topics.subscriptions,
        containsAll([topics.status, topics.state, topics.ack, topics.alert]),
      );
    });
  });

  group('MqttService commands before a connection exists', () {
    late MqttService service;

    setUp(() => service = MqttService());
    tearDown(() => service.dispose());

    test(
      'setBatteryPlan fails without fabricating a confirmation',
      () async {
        final outcome = await service.setBatteryPlan(
          budget: 200,
          reserve: 20,
          minSoc: 20,
        );
        expect(outcome.status, CommandStatus.failed);
        expect(outcome.message, 'Not connected to the system');
      },
    );

    test('removeLoad fails without fabricating a confirmation', () async {
      final outcome = await service.removeLoad(
        nodeMac: 'AA:BB:CC:DD:EE:FF',
        relayPin: 4,
      );
      expect(outcome.status, CommandStatus.failed);
      expect(outcome.message, 'Not connected to the system');
    });

    test('setSensorMode fails without fabricating a confirmation', () async {
      final outcome = await service.setSensorMode(useHardwareSensor: false);
      expect(outcome.status, CommandStatus.failed);
      expect(outcome.message, 'Not connected to the system');
    });

    test('triggerOptimizeNow fails without fabricating a confirmation', () async {
      final outcome = await service.triggerOptimizeNow();
      expect(outcome.status, CommandStatus.failed);
      expect(outcome.message, 'Not connected to the system');
    });
  });
}
