/// MQTT broker connection boundary.
///
/// Firebase Authentication answers "who is using the app?" — it has no
/// bearing on whether this device is allowed to talk to the MQTT broker
/// (e.g. HiveMQ Cloud). Broker credentials are a separate, per-installation
/// secret that the user enters themselves on the "MQTT Settings" screen and
/// that the app then stores only on-device (host/port/username via
/// SharedPreferences, password via the OS keystore through
/// flutter_secure_storage — see [MqttCredentialsStore]). Nothing here is
/// ever hardcoded in source or baked in at build time, since every
/// installation talks to a different user's broker.
class MqttConfig {
  const MqttConfig({
    required this.host,
    required this.port,
    required this.useTls,
    this.webSocketPath = '/mqtt',
    this.topicNamespace = 'kilowatts/v1',
    this.username,
    this.password,
  });

  const MqttConfig.unconfigured()
    : host = '',
      port = 8883,
      useTls = true,
      webSocketPath = '/mqtt',
      topicNamespace = 'kilowatts/v1',
      username = null,
      password = null;

  final String host;
  final int port;
  final bool useTls;

  /// Browser clients cannot open raw MQTT/TCP sockets. The broker must
  /// expose a WebSocket listener (normally WSS) at this path.
  final String webSocketPath;

  /// Each physical installation gets its own topic root, for example
  /// `kilowatts/v1/home-42`. This prevents unrelated installations sharing
  /// one broker from seeing or controlling each other's devices.
  final String topicNamespace;
  final String? username;
  final String? password;

  bool get isConfigured =>
      host.isNotEmpty &&
      host.trim() == host &&
      !host.contains('://') &&
      !host.contains('/') &&
      !host.contains(':') &&
      !host.contains(RegExp(r'\s')) &&
      port >= 1 &&
      port <= 65535 &&
      topicNamespace.isNotEmpty &&
      topicNamespace.trim() == topicNamespace &&
      !topicNamespace.startsWith('/') &&
      !topicNamespace.endsWith('/') &&
      !topicNamespace.contains('#') &&
      !topicNamespace.contains('+') &&
      !topicNamespace.contains(RegExp(r'\s'));

  String get browserWebSocketUrl {
    final path = webSocketPath.startsWith('/')
        ? webSocketPath
        : '/$webSocketPath';
    final scheme = useTls ? 'wss' : 'ws';
    return '$scheme://$host:$port$path';
  }

  MqttConfig copyWith({
    String? host,
    int? port,
    bool? useTls,
    String? webSocketPath,
    String? topicNamespace,
    String? username,
    String? password,
  }) {
    return MqttConfig(
      host: host ?? this.host,
      port: port ?? this.port,
      useTls: useTls ?? this.useTls,
      webSocketPath: webSocketPath ?? this.webSocketPath,
      topicNamespace: topicNamespace ?? this.topicNamespace,
      username: username ?? this.username,
      password: password ?? this.password,
    );
  }
}
