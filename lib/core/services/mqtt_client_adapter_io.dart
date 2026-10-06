import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import 'mqtt_config.dart';

MqttClient buildMqttClient(MqttConfig config, String clientId) {
  final client = MqttServerClient.withPort(config.host, clientId, config.port)
    ..secure = config.useTls
    ..keepAlivePeriod = 30
    ..autoReconnect = false
    ..setProtocolV311()
    ..connectionMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .startClean()
        .withWillQos(MqttQos.atMostOnce);
  return client;
}
