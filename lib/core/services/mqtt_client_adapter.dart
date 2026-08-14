import 'package:mqtt_client/mqtt_client.dart';

import 'mqtt_client_adapter_stub.dart'
    if (dart.library.io) 'mqtt_client_adapter_io.dart'
    if (dart.library.html) 'mqtt_client_adapter_web.dart';
import 'mqtt_config.dart';

MqttClient buildPlatformMqttClient(MqttConfig config, String clientId) =>
    buildMqttClient(config, clientId);
