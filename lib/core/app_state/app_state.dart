import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/alerts/models/alert_model.dart';
import '../../features/auth/data/access_control_service.dart';
import '../../features/auth/data/auth_service.dart';
import '../../features/loads/models/load_model.dart';
import '../../features/loads/models/load_configuration.dart';
import '../../features/system/models/system_state_model.dart';
import '../../features/system/models/system_node_model.dart';
import '../../features/system/models/topology_model.dart';
import '../constants/app_constants.dart';
import '../models/telemetry_point.dart';
import '../services/command_outcome.dart' show CommandOutcome;
import '../services/local_state_service.dart';
import '../services/mqtt_config.dart';
import '../services/mqtt_cloud_config_store.dart';
import '../services/mqtt_presence_store.dart';
import '../services/mqtt_service.dart';
import '../services/telemetry_history_store.dart';

export '../services/command_outcome.dart';
export '../services/mqtt_config.dart';
export '../services/mqtt_service.dart'
    show CentralAvailability, MqttConnectionStatus;

const _maxStoredAlerts = 100;
const _historyRetention = Duration(days: 7);
const _maxHistoryPoints = 2048;

/// Shared application state. Homeowners connect to their assigned installation;
/// installers use the separate provisioning service and never enter this scope.
class AppState {
  AppState({
    required this.authService,
    required MqttService mqttService,
    required LocalStateService localStateService,
    AccessControlService? accessControlService,
    this._mqttCloudConfigStore,
    this.mqttPresenceStore,
    this.telemetryHistoryStore,
  }) : _mqtt = mqttService,
       _localState = localStateService,
       _accessControlService = accessControlService ?? AccessControlService() {
    _wireMqttSubscriptions();
    unawaited(_loadThemeMode());
  }

  final AuthService authService;
  final MqttService _mqtt;
  final LocalStateService _localState;
  final MqttCloudConfigStore? _mqttCloudConfigStore;
  final MqttPresenceStore? mqttPresenceStore;
  final AccessControlService _accessControlService;
  final TelemetryHistoryStore? telemetryHistoryStore;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Future<void> _historyWriteQueue = Future<void>.value();
  Timer? _presenceTimer;
  Timer? _availabilityTimer;
  bool _disposed = false;
  final ValueNotifier<ThemeMode> themeMode = ValueNotifier(ThemeMode.system);

  final ValueNotifier<MqttConnectionStatus> connectionStatus = ValueNotifier(
    MqttConnectionStatus.disconnected,
  );
  String? _activeInstallationId;
  String? _loadedCacheScope;
  int _userScopeGeneration = 0;
  int _connectRequestId = 0;
  final ValueNotifier<SystemStateModel?> systemState = ValueNotifier(null);
  final ValueNotifier<DateTime?> lastLiveSystemUpdate = ValueNotifier(null);
  final ValueNotifier<DateTime?> lastCentralActivity = ValueNotifier(null);
  final ValueNotifier<CentralAvailability> centralAvailability = ValueNotifier(
    CentralAvailability.unknown,
  );
  final ValueNotifier<TopologyModel?> topology = ValueNotifier(null);
  final ValueNotifier<List<LoadModel>> loads = ValueNotifier(const []);
  final ValueNotifier<List<AlertModel>> alerts = ValueNotifier(const []);
  final ValueNotifier<List<SystemNodeModel>> systemNodes = ValueNotifier(
    const [],
  );

  final ValueNotifier<List<TelemetryPoint>> socHistory = ValueNotifier(
    const [],
  );
  final ValueNotifier<List<TelemetryPoint>> batteryPowerHistory = ValueNotifier(
    const [],
  );
  final ValueNotifier<List<TelemetryPoint>> activeLoadPowerHistory =
      ValueNotifier(const []);

  bool get isSystemStateLive =>
      !_disposed &&
      connectionStatus.value == MqttConnectionStatus.connected &&
      centralAvailability.value == CentralAvailability.online &&
      lastLiveSystemUpdate.value != null;

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode.value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('kilowatts.themeMode', mode.name);
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('kilowatts.themeMode');
    for (final mode in ThemeMode.values) {
      if (mode.name == saved && !_disposed) {
        themeMode.value = mode;
        break;
      }
    }
  }

  Stream<User?> get userChanges => authService.userChanges;

  Future<InstallationAccess> resolveCurrentAccess() =>
      _accessControlService.resolve(currentUser);

  void _wireMqttSubscriptions() {
    connectionStatus.value = _mqtt.currentStatus;

    _subscriptions.add(
      _mqtt.connectionStatusStream.listen((status) {
        if (_disposed) return;
        connectionStatus.value = status;
        unawaited(_publishPresence(status));
        _presenceTimer?.cancel();
        if (status == MqttConnectionStatus.connected) {
          _presenceTimer = Timer.periodic(const Duration(seconds: 30), (_) {
            unawaited(_publishPresence(MqttConnectionStatus.connected));
          });
        }
      }),
    );
    _subscriptions.add(
      _mqtt.centralAvailabilityStream.listen((availability) {
        if (_disposed) return;
        centralAvailability.value = availability;
        _availabilityTimer?.cancel();
        if (availability == CentralAvailability.online) {
          final now = DateTime.now();
          lastCentralActivity.value = now;
          _availabilityTimer = Timer(
            AppConstants.deviceAvailabilityTimeout,
            () {
              if (_disposed ||
                  centralAvailability.value != CentralAvailability.online) {
                return;
              }
              centralAvailability.value = CentralAvailability.stale;
            },
          );
        }
      }),
    );
    _subscriptions.add(
      _mqtt.systemStateStream.listen((state) {
        if (_disposed) return;
        systemState.value = state;
        lastLiveSystemUpdate.value = DateTime.now();
        final sampleAt =
            state.lastOptimizationAt ?? state.receivedAt ?? DateTime.now();
        _appendHistoryPoint(socHistory, state.batterySocPercent, sampleAt);
        _appendHistoryPoint(batteryPowerHistory, state.batteryPowerW, sampleAt);
        _appendHistoryPoint(
          activeLoadPowerHistory,
          state.estimatedTotalLoadPowerW,
          sampleAt,
        );
        _queueTelemetryHistoryWrite();
      }),
    );
    _subscriptions.add(
      _mqtt.topologyStream.listen((value) {
        if (_disposed) return;
        topology.value = value;
      }),
    );
    _subscriptions.add(
      _mqtt.loadsStream.listen((value) {
        if (_disposed) return;
        loads.value = value;
      }),
    );
    _subscriptions.add(
      _mqtt.alertStream.listen((alert) {
        if (_disposed) return;
        final next = <AlertModel>[alert, ...alerts.value];
        alerts.value = next.length > _maxStoredAlerts
            ? next.sublist(0, _maxStoredAlerts)
            : next;
        unawaited(_persistAlerts());
      }),
    );
    _subscriptions.add(
      _mqtt.systemNodesStream.listen((nodes) {
        if (_disposed) return;
        systemNodes.value = nodes;
      }),
    );
  }

  Future<void> _publishPresence(MqttConnectionStatus status) async {
    final store = mqttPresenceStore;
    final user = currentUser;
    if (store == null || user == null) return;
    final installationId = _activeInstallationId;
    if (installationId == null || installationId.isEmpty) return;
    await store.write(
      installationId: installationId,
      userUid: user.uid,
      status: status.name,
    );
  }

  void _appendHistoryPoint(
    ValueNotifier<List<TelemetryPoint>> notifier,
    double? value,
    DateTime timestamp,
  ) {
    if (_disposed || value == null || !value.isFinite) return;

    final next = [...notifier.value];
    final existingIndex = next.indexWhere(
      (point) =>
          point.timestamp.millisecondsSinceEpoch ==
          timestamp.millisecondsSinceEpoch,
    );
    final point = TelemetryPoint(timestamp: timestamp, value: value);
    if (existingIndex >= 0) {
      next[existingIndex] = point;
    } else {
      next.add(point);
    }

    notifier.value = _compactHistory(next, DateTime.now());
  }

  List<TelemetryPoint> _compactHistory(
    List<TelemetryPoint> input,
    DateTime now,
  ) {
    final cutoff = now.subtract(_historyRetention);
    final retained =
        input
            .where((point) => !point.timestamp.isBefore(cutoff))
            .toList(growable: false)
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    if (retained.length <= _maxHistoryPoints) return retained;

    final targetBuckets = _maxHistoryPoints ~/ 2;
    final bucketSize = (retained.length / targetBuckets).ceil();
    final compacted = <TelemetryPoint>[];

    for (var start = 0; start < retained.length; start += bucketSize) {
      final candidateEnd = start + bucketSize;
      final end = candidateEnd < retained.length
          ? candidateEnd
          : retained.length;
      final bucket = retained.sublist(start, end);
      if (bucket.length == 1) {
        compacted.add(bucket.first);
        continue;
      }

      var minimum = bucket.first;
      var maximum = bucket.first;
      for (final point in bucket.skip(1)) {
        if (point.value < minimum.value) minimum = point;
        if (point.value > maximum.value) maximum = point;
      }

      if (identical(minimum, maximum)) {
        compacted.add(bucket.last);
      } else if (minimum.timestamp.isBefore(maximum.timestamp)) {
        compacted
          ..add(minimum)
          ..add(maximum);
      } else {
        compacted
          ..add(maximum)
          ..add(minimum);
      }
    }

    return compacted.length <= _maxHistoryPoints
        ? compacted
        : compacted.sublist(compacted.length - _maxHistoryPoints);
  }

  List<TelemetryPoint> _mergeHistory(
    List<TelemetryPoint> cached,
    List<TelemetryPoint> live,
  ) {
    final byTime = <int, TelemetryPoint>{};
    for (final point in [...cached, ...live]) {
      byTime[point.timestamp.millisecondsSinceEpoch] = point;
    }
    return _compactHistory(byTime.values.toList(), DateTime.now());
  }

  void _queueTelemetryHistoryWrite() {
    if (_disposed) return;
    final uid = _activeInstallationId;
    final store = telemetryHistoryStore;
    if (uid == null || uid.isEmpty || store == null) return;

    final socSnapshot = List<TelemetryPoint>.of(socHistory.value);
    final batterySnapshot = List<TelemetryPoint>.of(batteryPowerHistory.value);
    final loadSnapshot = List<TelemetryPoint>.of(activeLoadPowerHistory.value);

    final snapshot = TelemetryHistorySnapshot(
      soc: socSnapshot,
      batteryPower: batterySnapshot,
      activeLoadPower: loadSnapshot,
    );
    _historyWriteQueue = _historyWriteQueue.then((_) async {
      try {
        await store.write(uid, snapshot);
      } catch (_) {
        // The next real telemetry update retries the complete Firebase
        // snapshot; no local history is substituted.
      }
    });
  }

  Future<void> _loadCachedSnapshot() async {
    if (_disposed) return;
    final scope = _activeInstallationId;
    if (scope == null || scope.isEmpty || _loadedCacheScope == scope) return;
    final generation = _userScopeGeneration;
    _loadedCacheScope = scope;

    if (systemState.value == null) {
      final cached = await _localState.readCachedSystemState(scope: scope);
      if (!_isCurrentUserScope(scope, generation)) return;
      if (cached != null && systemState.value == null) {
        systemState.value = SystemStateModel.fromJson(cached);
      }
    }

    final cachedAlerts = await _localState.readCachedAlerts(scope: scope);
    if (!_isCurrentUserScope(scope, generation)) return;
    if (cachedAlerts != null && alerts.value.isEmpty) {
      alerts.value = cachedAlerts.map(AlertModel.fromJson).toList();
    }

    final store = telemetryHistoryStore;
    var history = TelemetryHistorySnapshot.empty;
    if (store != null) {
      history = await store.read(scope);
      if (!_isCurrentUserScope(scope, generation)) return;
    }

    socHistory.value = _mergeHistory(history.soc, socHistory.value);
    batteryPowerHistory.value = _mergeHistory(
      history.batteryPower,
      batteryPowerHistory.value,
    );
    activeLoadPowerHistory.value = _mergeHistory(
      history.activeLoadPower,
      activeLoadPowerHistory.value,
    );
  }

  Future<void> _persistAlerts() => _localState.cacheAlerts(
    alerts.value.map((a) => a.toJson()).toList(),
    scope: _activeInstallationId,
  );

  Future<void> connectMqtt() async {
    final requestId = ++_connectRequestId;
    try {
      final config = await loadMqttConfig();
      if (_disposed || requestId != _connectRequestId) return;
      await _loadCachedSnapshot();
      if (_disposed || requestId != _connectRequestId) return;
      if (!config.isConfigured) {
        await _mqtt.disconnect();
        return;
      }
      await _mqtt.connect();
    } catch (_) {
      if (_disposed || requestId != _connectRequestId) return;
      // Loading the config (e.g. a Firestore permission error, or Auth not
      // yet ready) failed before a connection attempt could even start.
      // Surface a retryable status instead of leaving connectionStatus
      // stuck on its initial "disconnected" value forever.
      connectionStatus.value = MqttConnectionStatus.networkFailure;
    }
  }

  MqttConfig get mqttConfig => _mqtt.currentConfig;
  String? get activeInstallationId => _activeInstallationId;

  void _applyInstallationScope(String? installationId) {
    final scope = installationId?.trim();
    final normalized = scope == null || scope.isEmpty ? null : scope;
    if (_activeInstallationId == normalized) return;

    _activeInstallationId = normalized;
    _userScopeGeneration++;
    _loadedCacheScope = null;
    _mqtt.applyCacheScope(normalized);
    _availabilityTimer?.cancel();

    systemState.value = null;
    lastLiveSystemUpdate.value = null;
    lastCentralActivity.value = null;
    centralAvailability.value = CentralAvailability.unknown;
    topology.value = null;
    loads.value = const [];
    alerts.value = const [];
    systemNodes.value = const [];
    socHistory.value = const [];
    batteryPowerHistory.value = const [];
    activeLoadPowerHistory.value = const [];
  }

  bool _isCurrentUserScope(String uid, int generation) =>
      !_disposed &&
      _activeInstallationId == uid &&
      _userScopeGeneration == generation;

  Future<MqttConfig> loadMqttConfig() async {
    final cloudStore = _mqttCloudConfigStore;
    if (cloudStore == null) return _mqtt.loadMqttConfig();
    final access = await _accessControlService.resolve(currentUser);
    final installationId = access.role == KilowattsRole.homeowner
        ? access.installationId
        : null;
    _applyInstallationScope(installationId);
    if (installationId == null || installationId.isEmpty) {
      const unconfigured = MqttConfig.unconfigured();
      _mqtt.applyConfig(unconfigured);
      return unconfigured;
    }
    final generation = _userScopeGeneration;
    final cloud = await cloudStore.read(installationId: installationId);
    if (!_isCurrentUserScope(installationId, generation)) {
      return const MqttConfig.unconfigured();
    }
    final resolved = cloud ?? const MqttConfig.unconfigured();
    _mqtt.applyConfig(resolved);
    return resolved;
  }

  Future<MqttConnectionStatus> testMqttConnection(MqttConfig config) =>
      _mqtt.testConnection(config);
  Future<MqttConfig?> readSharedMqttConfig(String installationId) =>
      _mqttCloudConfigStore?.read(installationId: installationId) ??
      Future.value(null);

  Future<void> saveSharedMqttConfig(
    String installationId,
    MqttConfig config,
  ) async {
    final store = _mqttCloudConfigStore;
    if (store == null) return;
    await store.save(config, installationId: installationId);
  }

  Future<void> removeMqttConfig({required String installationId}) =>
      _mqttCloudConfigStore?.delete(installationId: installationId) ??
      Future.value();

  Future<CommandOutcome> setLoadFixedState({
    required String nodeMac,
    required int relayPin,
    required bool on,
  }) {
    return _mqtt.sendLoadCommand(
      nodeMac: nodeMac,
      relayPin: relayPin,
      mode: LoadMode.fixed,
      requestedState: on,
    );
  }

  Future<CommandOutcome> updateLoadConfiguration({
    required String nodeMac,
    required int relayPin,
    LoadMode? mode,
    bool? currentRequestedState,
    int? priority,
    LoadSchedule? schedule,
  }) {
    return _mqtt.sendLoadCommand(
      nodeMac: nodeMac,
      relayPin: relayPin,
      mode: mode,
      requestedState: currentRequestedState,
      priority: priority,
      schedule: schedule,
    );
  }

  Future<CommandOutcome> setBatteryReserve(double reserveSoCPercent) =>
      _mqtt.setBatteryReserve(reserveSoCPercent);

  Future<CommandOutcome> configureLoad(LoadConfiguration configuration) =>
      _mqtt.configureLoad(configuration);

  Future<CommandOutcome> removeLoad({
    required String nodeMac,
    required int relayPin,
  }) => _mqtt.removeLoad(nodeMac: nodeMac, relayPin: relayPin);

  Stream<List<KilowattsUserAccess>> watchAccessUsers() =>
      _accessControlService.watchUsers();

  Stream<MqttPresence?> watchMqttPresence({
    required String installationId,
    required String userUid,
  }) =>
      mqttPresenceStore?.watch(
        installationId: installationId,
        userUid: userUid,
      ) ??
      Stream.value(null);

  Future<void> setUserRole({
    required String email,
    required String uid,
    required KilowattsRole role,
  }) => _accessControlService.setRole(email: email, uid: uid, role: role);

  Future<void> setAlertRead(String id, bool read) async {
    if (_disposed) return;
    alerts.value = [
      for (final alert in alerts.value)
        if (alert.id == id) alert.copyWith(acknowledged: read) else alert,
    ];
    await _persistAlerts();
  }

  Future<void> acknowledgeAlert(String id) => setAlertRead(id, true);

  Future<void> acknowledgeAllAlerts() async {
    if (_disposed) return;
    alerts.value = [
      for (final alert in alerts.value) alert.copyWith(acknowledged: true),
    ];
    await _persistAlerts();
  }

  Future<void> deleteAlert(String id) async {
    if (_disposed) return;
    alerts.value = alerts.value
        .where((alert) => alert.id != id)
        .toList(growable: false);
    await _persistAlerts();
  }

  User? get currentUser => authService.currentUser;

  Future<void> signOut() async {
    await _mqtt.disconnect();
    await _historyWriteQueue;
    _applyInstallationScope(null);
    await authService.signOut();
  }

  void dispose() {
    if (_disposed) return;

    _disposed = true;
    _presenceTimer?.cancel();
    _availabilityTimer?.cancel();

    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    connectionStatus.dispose();
    themeMode.dispose();
    systemState.dispose();
    lastLiveSystemUpdate.dispose();
    lastCentralActivity.dispose();
    centralAvailability.dispose();
    topology.dispose();
    loads.dispose();
    alerts.dispose();
    systemNodes.dispose();
    socHistory.dispose();
    batteryPowerHistory.dispose();
    activeLoadPowerHistory.dispose();
  }
}
