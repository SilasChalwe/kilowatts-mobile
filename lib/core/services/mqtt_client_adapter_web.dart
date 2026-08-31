import 'package:mqtt_client/mqtt_browser_client.dart';
import 'package:mqtt_client/mqtt_client.dart';

import 'mqtt_config.dart';

MqttClient buildMqttClient(MqttConfig config, String clientId) {
  // Browser and native listeners are commonly different ports. Keep the
  // choice explicit in the installation configuration instead of silently
  // assuming one broker vendor's 8883/8884 convention.
  final wsPort = config.resolvedWebSocketPort;
  final wsUrl = config.browserWebSocketUrl;

  final client = MqttBrowserClient.withPort(wsUrl, clientId, wsPort)
    ..keepAlivePeriod = 30
    ..autoReconnect = false
    ..setProtocolV311()
    ..connectionMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .startClean()
        .withWillQos(MqttQos.atMostOnce);

  return client;
}
