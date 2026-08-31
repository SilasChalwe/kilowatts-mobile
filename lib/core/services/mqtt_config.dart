/// MQTT broker configuration supplied for the active installation.
class MqttConfig {
  const MqttConfig({
    required this.host,
    required this.port,
    required this.useTls,
    this.topicNamespace = 'kilowatts/v1',
    this.username,
    this.password,
  });

  const MqttConfig.unconfigured()
    : host = '',
      port = 8883,
      useTls = true,
      topicNamespace = 'kilowatts/v1',
      username = null,
      password = null;

  final String host;
  final int port;
  final bool useTls;
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

  MqttConfig copyWith({
    String? host,
    int? port,
    bool? useTls,
    String? topicNamespace,
    String? username,
    String? password,
  }) {
    return MqttConfig(
      host: host ?? this.host,
      port: port ?? this.port,
      useTls: useTls ?? this.useTls,
      topicNamespace: topicNamespace ?? this.topicNamespace,
      username: username ?? this.username,
      password: password ?? this.password,
    );
  }
}
