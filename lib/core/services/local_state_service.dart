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
  static const _installerBatteryConfigKey =
      'kilowatts.installer.battery_config';
  static const _installerOptimizerIntervalKey =
      'kilowatts.installer.optimizer_interval_seconds';

  String _scopedKey(String key, String? scope) {
    final value = scope?.trim() ?? '';
    if (value.isEmpty) return key;
    return '$key.${base64Url.encode(utf8.encode(value))}';
  }

  Future<bool> isSetupComplete({String? scope}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_scopedKey(_setupCompleteKey, scope)) ?? false;
  }

  Future<void> setSetupComplete(bool complete, {String? scope}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_scopedKey(_setupCompleteKey, scope), complete);
  }

  Future<void> cacheSystemState(
    Map<String, dynamic> json, {
    String? scope,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _scopedKey(_lastSystemStateKey, scope),
      jsonEncode(json),
    );
    await prefs.setString(
      _scopedKey(_lastSyncedAtKey, scope),
      DateTime.now().toIso8601String(),
    );
  }

  Future<void> cacheLoads(
    List<Map<String, dynamic>> loads, {
    String? scope,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_scopedKey(_lastLoadsKey, scope), jsonEncode(loads));
  }

  Future<Map<String, dynamic>?> readCachedSystemState({String? scope}) async {
    final prefs = await SharedPreferences.getInstance();
    return _readJsonMap(
      prefs.getString(_scopedKey(_lastSystemStateKey, scope)),
    );
  }

  Future<List<Map<String, dynamic>>?> readCachedLoads({String? scope}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_scopedKey(_lastLoadsKey, scope));
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

  Future<DateTime?> readLastSyncedAt({String? scope}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_scopedKey(_lastSyncedAtKey, scope));
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> clearSetupState({String? scope}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_scopedKey(_setupCompleteKey, scope));
  }

  Future<Map<String, String>> readNodeNameOverrides({String? scope}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_scopedKey(_nodeNameOverridesKey, scope));
    if (raw == null) return {};
    try {
      return (jsonDecode(raw) as Map).cast<String, String>();
    } catch (_) {
      return {};
    }
  }

  Future<void> setNodeNameOverride(
    String mac,
    String name, {
    String? scope,
  }) async {
    final overrides = await readNodeNameOverrides(scope: scope);
    overrides[mac] = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _scopedKey(_nodeNameOverridesKey, scope),
      jsonEncode(overrides),
    );
  }

  Future<void> cacheAlerts(
    List<Map<String, dynamic>> alerts, {
    String? scope,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_scopedKey(_alertsKey, scope), jsonEncode(alerts));
  }

  Future<List<Map<String, dynamic>>?> readCachedAlerts({String? scope}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_scopedKey(_alertsKey, scope));
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

  Future<void> cacheInstallerSafetyConfig(
    Map<String, dynamic> values, {
    String? scope,
  }) async {
    await _writeInstallerSnapshot(
      _installerSafetyConfigKey,
      values,
      scope: scope,
    );
  }

  Future<Map<String, dynamic>?> readInstallerSafetyConfig({
    String? scope,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    return _readJsonMap(
      prefs.getString(_scopedKey(_installerSafetyConfigKey, scope)),
    );
  }

  Future<void> cacheInstallerBatteryConfig(
    Map<String, dynamic> values, {
    String? scope,
  }) async {
    await _writeInstallerSnapshot(
      _installerBatteryConfigKey,
      values,
      scope: scope,
    );
  }

  Future<Map<String, dynamic>?> readInstallerBatteryConfig({
    String? scope,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    return _readJsonMap(
      prefs.getString(_scopedKey(_installerBatteryConfigKey, scope)),
    );
  }

  Future<void> cacheInstallerOptimizerIntervalSeconds(
    int seconds, {
    String? scope,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _scopedKey(_installerOptimizerIntervalKey, scope),
      seconds,
    );
  }

  Future<int?> readInstallerOptimizerIntervalSeconds({String? scope}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_scopedKey(_installerOptimizerIntervalKey, scope));
  }

  Future<void> _writeInstallerSnapshot(
    String key,
    Map<String, dynamic> values, {
    String? scope,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _scopedKey(key, scope),
      jsonEncode({...values, 'savedAt': DateTime.now().toIso8601String()}),
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
