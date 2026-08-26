import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Local, on-device persistence only. Live embedded-system state always comes
/// from MQTT; locally cached installer configuration is labelled as such in
/// the UI and is never presented as fresh Central telemetry.
class LocalStateService {
  static const _setupCompleteKey = 'kilowatts.setup_complete';
  static const _lastSystemStateKey = 'kilowatts.last_system_state';
  static const _lastLoadsKey = 'kilowatts.last_loads';
  static const _lastSyncedAtKey = 'kilowatts.last_synced_at';
  static const _nodeNameOverridesKey = 'kilowatts.node_name_overrides';
  static const _alertsKey = 'kilowatts.alerts';
  static const _installerSafetyConfigKey = 'kilowatts.installer.safety_config';
  static const _installerBatteryConfigKey = 'kilowatts.installer.battery_config';
  static const _installerOptimizerIntervalKey =
      'kilowatts.installer.optimizer_interval_seconds';

  Future<bool> isSetupComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_setupCompleteKey) ?? false;
  }

  Future<void> setSetupComplete(bool complete) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_setupCompleteKey, complete);
  }

  Future<void> cacheSystemState(Map<String, dynamic> json) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSystemStateKey, jsonEncode(json));
    await prefs.setString(_lastSyncedAtKey, DateTime.now().toIso8601String());
  }

  Future<void> cacheLoads(List<Map<String, dynamic>> loads) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastLoadsKey, jsonEncode(loads));
  }

  Future<Map<String, dynamic>?> readCachedSystemState() async {
    final prefs = await SharedPreferences.getInstance();
    return _readJsonMap(prefs.getString(_lastSystemStateKey));
  }

  Future<List<Map<String, dynamic>>?> readCachedLoads() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lastLoadsKey);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw) as List;
      return decoded
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<DateTime?> readLastSyncedAt() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lastSyncedAtKey);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> clearSetupState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_setupCompleteKey);
  }

  Future<Map<String, String>> readNodeNameOverrides() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_nodeNameOverridesKey);
    if (raw == null) return {};
    try {
      return (jsonDecode(raw) as Map).cast<String, String>();
    } catch (_) {
      return {};
    }
  }

  Future<void> setNodeNameOverride(String mac, String name) async {
    final overrides = await readNodeNameOverrides();
    overrides[mac] = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nodeNameOverridesKey, jsonEncode(overrides));
  }

  Future<void> cacheAlerts(List<Map<String, dynamic>> alerts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_alertsKey, jsonEncode(alerts));
  }

  Future<List<Map<String, dynamic>>?> readCachedAlerts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_alertsKey);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw) as List;
      return decoded
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> cacheInstallerSafetyConfig(Map<String, dynamic> values) async {
    await _writeInstallerSnapshot(_installerSafetyConfigKey, values);
  }

  Future<Map<String, dynamic>?> readInstallerSafetyConfig() async {
    final prefs = await SharedPreferences.getInstance();
    return _readJsonMap(prefs.getString(_installerSafetyConfigKey));
  }

  Future<void> cacheInstallerBatteryConfig(Map<String, dynamic> values) async {
    await _writeInstallerSnapshot(_installerBatteryConfigKey, values);
  }

  Future<Map<String, dynamic>?> readInstallerBatteryConfig() async {
    final prefs = await SharedPreferences.getInstance();
    return _readJsonMap(prefs.getString(_installerBatteryConfigKey));
  }

  Future<void> cacheInstallerOptimizerIntervalSeconds(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_installerOptimizerIntervalKey, seconds);
  }

  Future<int?> readInstallerOptimizerIntervalSeconds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_installerOptimizerIntervalKey);
  }

  Future<void> _writeInstallerSnapshot(
    String key,
    Map<String, dynamic> values,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      key,
      jsonEncode({
        ...values,
        'savedAt': DateTime.now().toIso8601String(),
      }),
    );
  }

  Map<String, dynamic>? _readJsonMap(String? raw) {
    if (raw == null) return null;
    try {
      return (jsonDecode(raw) as Map).cast<String, dynamic>();
    } catch (_) {
      return null;
    }
  }
}
