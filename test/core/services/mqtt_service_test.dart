import 'package:flutter_test/flutter_test.dart';
import 'package:kilowatts_mobile/core/constants/app_constants.dart';
import 'package:kilowatts_mobile/core/services/command_outcome.dart';
import 'package:kilowatts_mobile/core/services/mqtt_service.dart';

void main() {
  group('MqttTopics', () {
    test('builds every topic under the configured namespace', () {
      const topics = MqttTopics('kilowatts/v1/home-42');

      expect(topics.commandsLoad, 'kilowatts/v1/home-42/commands/load');
      expect(topics.commandsConfig, 'kilowatts/v1/home-42/commands/config');
      expect(topics.commandsReserve, 'kilowatts/v1/home-42/commands/reserve');
      expect(topics.acks, 'kilowatts/v1/home-42/acks');
    });

    test('subscriptions never include a publish-only command topic', () {
      const topics = MqttTopics('kilowatts/v1');

      expect(topics.subscriptions, isNot(contains(topics.commandsLoad)));
      expect(topics.subscriptions, isNot(contains(topics.commandsConfig)));
      expect(topics.subscriptions, isNot(contains(topics.commandsReserve)));
    });
  });

  group('MqttService commands before a connection exists', () {
    late MqttService service;

    setUp(() => service = MqttService());
    tearDown(() => service.dispose());

    test(
      'setBatteryReserve fails without fabricating a confirmation',
      () async {
        final outcome = await service.setBatteryReserve(25);
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
  });
}
