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
    this.username,
    this.password,
  });

  const MqttConfig.unconfigured()
    : host = '',
      port = 8883,
      useTls = true,
      username = null,
      password = null;

  final String host;
  final int port;
  final bool useTls;
  final String? username;
  final String? password;

  bool get isConfigured => host.isNotEmpty;

  MqttConfig copyWith({
    String? host,
    int? port,
    bool? useTls,
    String? username,
    String? password,
  }) {
    return MqttConfig(
      host: host ?? this.host,
      port: port ?? this.port,
      useTls: useTls ?? this.useTls,
      username: username ?? this.username,
      password: password ?? this.password,
    );
  }
}
