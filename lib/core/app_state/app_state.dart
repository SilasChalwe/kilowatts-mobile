import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/admin/models/installer_node_model.dart';
import '../../features/alerts/models/alert_model.dart';
import '../../features/auth/data/access_control_service.dart';
import '../../features/auth/data/auth_service.dart';
import '../../features/loads/models/load_model.dart';
import '../../features/setup/models/setup_session.dart';
import '../../features/system/models/system_state_model.dart';
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

/// Shared application state for both homeowner and installer experiences.
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
  String? _selectedUserUid;
  String? _activeUserUid;
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
  final ValueNotifier<List<InstallerNodeModel>> installerNodes = ValueNotifier(
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

  Future<void> setSetupComplete(bool complete) =>
      _localState.setSetupComplete(complete, scope: _activeUserUid);

  Future<void> setNodeNameOverride(String mac, String name) =>
      _localState.setNodeNameOverride(mac, name, scope: _activeUserUid);

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
      _mqtt.installerNodesStream.listen((nodes) {
        if (_disposed) return;
        installerNodes.value = nodes;
      }),
    );
  }

  Future<void> _publishPresence(MqttConnectionStatus status) async {
    final store = mqttPresenceStore;
    final user = currentUser;
    if (store == null || user == null) return;
    final ownerUid = _activeUserUid;
    if (ownerUid == null || ownerUid.isEmpty) return;
    await store.write(
      ownerUid: ownerUid,
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
    if (_selectedUserUid != null) return;
    final uid = _activeUserUid;
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
    final scope = _activeUserUid;
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
    if (store != null && _selectedUserUid == null) {
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
    scope: _activeUserUid,
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
  String? get selectedUserUid => _selectedUserUid;

  Future<void> selectUser(String uid) async {
    final id = uid.trim();
    if (id.isEmpty || id == _selectedUserUid) return;
    _selectedUserUid = id;
    _connectRequestId++;
    final disconnecting = _mqtt.disconnect();
    _applyUserScope(id);
    final generation = _userScopeGeneration;
    await disconnecting;
    if (!_isCurrentUserScope(id, generation) || _selectedUserUid != id) {
      return;
    }
    await connectMqtt();
  }

  void _applyUserScope(String? uid) {
    final scope = uid?.trim();
    final normalized = scope == null || scope.isEmpty ? null : scope;
    if (_activeUserUid == normalized) return;

    _activeUserUid = normalized;
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
    installerNodes.value = const [];
    socHistory.value = const [];
    batteryPowerHistory.value = const [];
    activeLoadPowerHistory.value = const [];
  }

  bool _isCurrentUserScope(String uid, int generation) =>
      !_disposed && _activeUserUid == uid && _userScopeGeneration == generation;

  Future<MqttConfig> loadMqttConfig() async {
    final cloudStore = _mqttCloudConfigStore;
    if (cloudStore == null) return _mqtt.loadMqttConfig();
    final access = await _accessControlService.resolve(currentUser);
    final userUid = access.role == KilowattsRole.installer
        ? _selectedUserUid
        : currentUser?.uid;
    _applyUserScope(userUid);
    if (userUid == null || userUid.isEmpty) {
      const unconfigured = MqttConfig.unconfigured();
      _mqtt.applyConfig(unconfigured);
      return unconfigured;
    }
    final generation = _userScopeGeneration;
    final cloud = await cloudStore.read(uid: userUid);
    if (!_isCurrentUserScope(userUid, generation)) {
      return const MqttConfig.unconfigured();
    }
    final resolved = cloud ?? const MqttConfig.unconfigured();
    _mqtt.applyConfig(resolved);
    return resolved;
  }

  Future<MqttConnectionStatus> testMqttConnection(MqttConfig config) =>
      _mqtt.testConnection(config);
  Future<void> saveMqttConfig(MqttConfig config) async {
    final access = await _accessControlService.resolve(currentUser);
    final uid = access.role == KilowattsRole.installer
        ? _selectedUserUid
        : currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw StateError('Select an installation before saving MQTT settings.');
    }
    if (_mqttCloudConfigStore != null) {
      await _mqttCloudConfigStore.save(config, uid: uid);
    }
    await _mqtt.saveAndConnect(config);
  }

  Future<MqttConfig?> readSharedMqttConfig(String uid) =>
      _mqttCloudConfigStore?.read(uid: uid) ?? Future.value(null);

  Future<void> saveSharedMqttConfig(String uid, MqttConfig config) async {
    final store = _mqttCloudConfigStore;
    if (store == null) return;
    await store.save(config, uid: uid);
  }

  Future<void> removeMqttConfig({required String uid}) async {
    await _mqttCloudConfigStore?.delete(uid: uid);
    await _mqtt.disconnect();
  }

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

  Future<CommandOutcome> applySafetyConfig(SafetyConfigDraft draft) {
    InstallerNodeModel? central;
    for (final node in installerNodes.value) {
      if (node.isCentralNode) {
        central = node;
        break;
      }
    }
    if (central == null || central.mac.isEmpty) {
      return Future.value(
        const CommandOutcome.failed(
          'Central Node identity is not available yet. Wait for state/nodes.',
        ),
      );
    }
    return _mqtt.sendSafetyConfig(centralNodeMac: central.mac, draft: draft);
  }

  Future<CommandOutcome> requestOptimizationCycle() =>
      _mqtt.requestOptimizationCycle();

  Future<CommandOutcome> setOptimizerIntervalSeconds(int seconds) =>
      _mqtt.setOptimizerIntervalSeconds(seconds);

  Future<CommandOutcome> setBatteryReserve(double reserveSoCPercent) =>
      _mqtt.setBatteryReserve(reserveSoCPercent);

  Future<int?> readLastInstallerOptimizerIntervalSeconds() =>
      _localState.readInstallerOptimizerIntervalSeconds(scope: _activeUserUid);

  Future<void> cacheLastInstallerOptimizerIntervalSeconds(int seconds) =>
      _localState.cacheInstallerOptimizerIntervalSeconds(
        seconds,
        scope: _activeUserUid,
      );

  Future<CommandOutcome> commissionNode({
    required String nodeMac,
    required String friendlyName,
  }) => _mqtt.commissionNode(nodeMac: nodeMac, friendlyName: friendlyName);

  Future<CommandOutcome> renameNode({
    required String nodeMac,
    required String friendlyName,
  }) => _mqtt.renameNode(nodeMac: nodeMac, friendlyName: friendlyName);

  Future<CommandOutcome> decommissionNode({required String nodeMac}) =>
      _mqtt.decommissionNode(nodeMac: nodeMac);

  Future<CommandOutcome> configureLoad(
    InstallerLoadConfiguration configuration,
  ) => _mqtt.configureLoad(configuration);

  Future<CommandOutcome> removeLoad({
    required String nodeMac,
    required int relayPin,
  }) => _mqtt.removeLoad(nodeMac: nodeMac, relayPin: relayPin);

  Future<CommandOutcome> configureBatterySensor({
    required String centralNodeMac,
    required int i2cAddress,
    required double shuntResistanceOhms,
    required double nominalVoltageVolts,
    required double maximumExpectedCurrentAmps,
    required double emaAlpha,
    required double batteryCapacityAmpHours,
    required double initialStateOfChargePercent,
  }) => _mqtt.configureBatterySensor(
    centralNodeMac: centralNodeMac,
    i2cAddress: i2cAddress,
    shuntResistanceOhms: shuntResistanceOhms,
    nominalVoltageVolts: nominalVoltageVolts,
    maximumExpectedCurrentAmps: maximumExpectedCurrentAmps,
    emaAlpha: emaAlpha,
    batteryCapacityAmpHours: batteryCapacityAmpHours,
    initialStateOfChargePercent: initialStateOfChargePercent,
  );

  Future<Map<String, dynamic>?> readLastInstallerSafetyConfig() =>
      _localState.readInstallerSafetyConfig(scope: _activeUserUid);

  Future<void> cacheLastInstallerSafetyConfig(Map<String, dynamic> values) =>
      _localState.cacheInstallerSafetyConfig(values, scope: _activeUserUid);

  Future<Map<String, dynamic>?> readLastInstallerBatteryConfig() =>
      _localState.readInstallerBatteryConfig(scope: _activeUserUid);

  Future<void> cacheLastInstallerBatteryConfig(Map<String, dynamic> values) =>
      _localState.cacheInstallerBatteryConfig(values, scope: _activeUserUid);

  Future<CommandOutcome> setSimulationEnabled(bool enabled) =>
      _mqtt.setSimulationEnabled(enabled);

  Future<CommandOutcome> setSimulationValues({
    double? batteryVoltageVolts,
    double? batteryCurrentAmps,
    double? stateOfChargePercent,
  }) => _mqtt.setSimulationValues(
    batteryVoltageVolts: batteryVoltageVolts,
    batteryCurrentAmps: batteryCurrentAmps,
    stateOfChargePercent: stateOfChargePercent,
  );

  Future<CommandOutcome> configureBatterySensorForSetup({
    required String centralNodeMac,
    required double nominalVoltageVolts,
    required double maximumExpectedCurrentAmps,
    required double batteryCapacityAmpHours,
    required double initialStateOfChargePercent,
  }) => configureBatterySensor(
    centralNodeMac: centralNodeMac,
    i2cAddress: 0x40,
    shuntResistanceOhms: 0.1,
    nominalVoltageVolts: nominalVoltageVolts,
    maximumExpectedCurrentAmps: maximumExpectedCurrentAmps,
    emaAlpha: 0.2,
    batteryCapacityAmpHours: batteryCapacityAmpHours,
    initialStateOfChargePercent: initialStateOfChargePercent,
  );

  Stream<List<KilowattsUserAccess>> watchAccessUsers() =>
      _accessControlService.watchUsers();

  Stream<MqttPresence?> watchMqttPresence({
    required String ownerUid,
    required String userUid,
  }) =>
      mqttPresenceStore?.watch(ownerUid: ownerUid, userUid: userUid) ??
      Stream.value(null);

  Future<void> saveAccessUser({
    required String email,
    required String fullName,
    required String phoneNumber,
    required String role,
  }) => _accessControlService.saveUser(
    email: email,
    fullName: fullName,
    phoneNumber: phoneNumber,
    role: role,
  );

  Future<void> assignRole({required String email, required String role}) =>
      _accessControlService.assignRole(email: email, role: role);

  Future<void> revokeAccess(String email) =>
      _accessControlService.revokeAccess(email);

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
    _selectedUserUid = null;
    _applyUserScope(null);
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
    installerNodes.dispose();
    socHistory.dispose();
    batteryPowerHistory.dispose();
    activeLoadPowerHistory.dispose();
  }
}
