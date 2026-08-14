import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mqtt_config.dart';

/// Where the user's MQTT broker connection details live on this device.
///
/// The user types these in on the MQTT Settings screen — they are never
/// hardcoded, never baked in at build time, and never logged. Host/port/TLS/
/// username are ordinary local preferences; the password is the one secret
/// in this boundary and is kept in the OS keystore via
/// flutter_secure_storage rather than plain SharedPreferences.
class MqttCredentialsStore {
  static const _hostKey = 'kilowatts.mqtt.host';
  static const _portKey = 'kilowatts.mqtt.port';
  static const _tlsKey = 'kilowatts.mqtt.use_tls';
  static const _usernameKey = 'kilowatts.mqtt.username';
  static const _passwordKey = 'kilowatts.mqtt.password';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  Future<MqttConfig?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final host = prefs.getString(_hostKey);
    if (host == null || host.isEmpty) return null;

    final password = await _secureStorage.read(key: _passwordKey);

    return MqttConfig(
      host: host,
      port: prefs.getInt(_portKey) ?? 8883,
      useTls: prefs.getBool(_tlsKey) ?? true,
      username: prefs.getString(_usernameKey),
      password: password,
    );
  }

  Future<void> save(MqttConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_hostKey, config.host);
    await prefs.setInt(_portKey, config.port);
    await prefs.setBool(_tlsKey, config.useTls);
    if (config.username == null) {
      await prefs.remove(_usernameKey);
    } else {
      await prefs.setString(_usernameKey, config.username!);
    }

    if (config.password == null) {
      await _secureStorage.delete(key: _passwordKey);
    } else {
      await _secureStorage.write(key: _passwordKey, value: config.password);
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_hostKey);
    await prefs.remove(_portKey);
    await prefs.remove(_tlsKey);
    await prefs.remove(_usernameKey);
    await _secureStorage.delete(key: _passwordKey);
  }
}
