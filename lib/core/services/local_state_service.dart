import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Local, on-device homeowner cache. Live embedded-system state always comes
/// from MQTT and cached data is never presented as fresh Central telemetry.
class LocalStateService {
  static const _lastSystemStateKey = 'kilowatts.last_system_state';
  static const _lastLoadsKey = 'kilowatts.last_loads';
  static const _lastSyncedAtKey = 'kilowatts.last_synced_at';
  static const _alertsKey = 'kilowatts.alerts';

  String _scopedKey(String key, String? scope) {
    final value = scope?.trim() ?? '';
    if (value.isEmpty) return key;
    return '$key.${base64Url.encode(utf8.encode(value))}';
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

  Map<String, dynamic>? _readJsonMap(String? raw) {
    if (raw == null) return null;
    try {
      return (jsonDecode(raw) as Map).cast<String, dynamic>();
    } catch (_) {
      return null;
    }
  }
}
