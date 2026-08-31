/// MQTT broker configuration supplied by Firebase for the active installation.
class MqttConfig {
  const MqttConfig({
    required this.host,
    required this.port,
    required this.useTls,
    this.webSocketPort,
    this.webSocketPath = '/mqtt',
    this.topicNamespace = 'kilowatts/v1',
    this.username,
    this.password,
  });

  const MqttConfig.unconfigured()
    : host = '',
      port = 8883,
      useTls = true,
      webSocketPort = 8884,
      webSocketPath = '/mqtt',
      topicNamespace = 'kilowatts/v1',
      username = null,
      password = null;

  final String host;
  final int port;
  final bool useTls;

  /// Browser clients cannot open raw MQTT/TCP sockets. The broker must
  /// expose a WebSocket listener (normally WSS) at this path.
  final int? webSocketPort;
  final String webSocketPath;

  int get resolvedWebSocketPort => webSocketPort ?? port;

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
      resolvedWebSocketPort >= 1 &&
      resolvedWebSocketPort <= 65535 &&
      webSocketPath.isNotEmpty &&
      webSocketPath.startsWith('/') &&
      !webSocketPath.contains(RegExp(r'\s')) &&
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
    return '$scheme://$host:$resolvedWebSocketPort$path';
  }

  MqttConfig copyWith({
    String? host,
    int? port,
    bool? useTls,
    int? webSocketPort,
    String? webSocketPath,
    String? topicNamespace,
    String? username,
    String? password,
  }) {
    return MqttConfig(
      host: host ?? this.host,
      port: port ?? this.port,
      useTls: useTls ?? this.useTls,
      webSocketPort: webSocketPort ?? this.webSocketPort,
      webSocketPath: webSocketPath ?? this.webSocketPath,
      topicNamespace: topicNamespace ?? this.topicNamespace,
      username: username ?? this.username,
      password: password ?? this.password,
    );
  }
}
