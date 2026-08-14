import 'package:flutter_test/flutter_test.dart';
import 'package:kilowatts_mobile/core/services/mqtt_config.dart';

void main() {
  test('builds a secure browser WebSocket URL from separate broker fields', () {
    const config = MqttConfig(
      host: 'broker.example.com',
      port: 8884,
      useTls: true,
      webSocketPath: '/mqtt',
      topicNamespace: 'kilowatts/v1/home-42',
    );

    expect(config.isConfigured, isTrue);
    expect(config.browserWebSocketUrl, 'wss://broker.example.com:8884/mqtt');
  });

  test('rejects a pasted URL, embedded port, or wildcard namespace', () {
    expect(
      const MqttConfig(
        host: 'wss://broker.example.com',
        port: 8884,
        useTls: true,
      ).isConfigured,
      isFalse,
    );
    expect(
      const MqttConfig(
        host: 'broker.example.com:8884',
        port: 8884,
        useTls: true,
      ).isConfigured,
      isFalse,
    );
    expect(
      const MqttConfig(
        host: 'broker.example.com',
        port: 8884,
        useTls: true,
        topicNamespace: 'kilowatts/v1/#',
      ).isConfigured,
      isFalse,
    );
  });
}
