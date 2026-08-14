import 'package:mqtt_client/mqtt_client.dart';

import 'mqtt_config.dart';

MqttClient buildMqttClient(MqttConfig config, String clientId) {
  throw UnsupportedError('MQTT is not supported on this platform.');
}
