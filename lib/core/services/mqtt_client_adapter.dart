import 'package:mqtt_client/mqtt_client.dart';

import 'mqtt_client_adapter_io.dart';
import 'mqtt_config.dart';

MqttClient buildPlatformMqttClient(MqttConfig config, String clientId) =>
    buildMqttClient(config, clientId);
