import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Local, on-device persistence only. There is no backend for app/setup
/// state — the embedded system's live state always comes from MQTT.
///
/// Used for two things:
///  - remembering that first-time setup finished, so returning users skip
///    straight to the dashboard.
///  - caching the last retained system/loads payloads so a returning user
///    with no connectivity yet sees their last-known state (clearly marked
///    stale by the UI) instead of a blank screen.
class LocalStateService {
  static const _setupCompleteKey = 'kilowatts.setup_complete';
  static const _lastSystemStateKey = 'kilowatts.last_system_state';
  static const _lastLoadsKey = 'kilowatts.last_loads';
  static const _lastSyncedAtKey = 'kilowatts.last_synced_at';
  static const _nodeNameOverridesKey = 'kilowatts.node_name_overrides';
  static const _alertsKey = 'kilowatts.alerts';

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
    final raw = prefs.getString(_lastSystemStateKey);
    if (raw == null) return null;
    try {
      return (jsonDecode(raw) as Map).cast<String, dynamic>();
    } catch (_) {
      return null;
    }
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

  /// Locally-remembered friendly names for nodes, keyed by MAC. This is a
  /// device-local convenience only — there is no firmware "rename node"
  /// command in the current MQTT contract, so this never claims to have
  /// changed anything on the Central Node itself.
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

  /// Alerts have no server-side history — this is the only reason a
  /// returning user still sees anything older than what streamed in since
  /// this app launch (including which ones were already marked read).
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
}
