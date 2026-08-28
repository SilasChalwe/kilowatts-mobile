import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

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
import '../services/mqtt_service.dart';

export '../services/command_outcome.dart';
export '../services/mqtt_config.dart';
export '../services/mqtt_service.dart' show MqttConnectionStatus;

const _maxStoredAlerts = 100;
const _historyRetention = Duration(days: 7);
const _historySampleInterval = Duration(seconds: 15);
const _historyPersistDelay = Duration(seconds: 15);
const _maxHistoryPoints = 4096;

/// Shared application state for both homeowner and installer experiences.
class AppState {
  AppState({
    required this.authService,
    required MqttService mqttService,
    required LocalStateService localStateService,
    AccessControlService? accessControlService,
  }) : _mqtt = mqttService,
       _localState = localStateService,
       _accessControlService = accessControlService ?? AccessControlService() {
    _wireMqttSubscriptions();
    unawaited(_loadCachedSnapshot());
  }

  final AuthService authService;
  final MqttService _mqtt;
  final LocalStateService _localState;
  final AccessControlService _accessControlService;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Timer? _historyPersistTimer;
  bool _disposed = false;

  final ValueNotifier<MqttConnectionStatus> connectionStatus = ValueNotifier(
    MqttConnectionStatus.disconnected,
  );
  final ValueNotifier<SystemStateModel?> systemState = ValueNotifier(null);
  final ValueNotifier<DateTime?> lastLiveSystemUpdate = ValueNotifier(null);
  final ValueNotifier<TopologyModel?> topology = ValueNotifier(null);
  final ValueNotifier<List<LoadModel>> loads = ValueNotifier(const []);
  final ValueNotifier<List<AlertModel>> alerts = ValueNotifier(const []);
  final ValueNotifier<List<InstallerNodeModel>> installerNodes = ValueNotifier(
    const [],
  );

  final ValueNotifier<List<TelemetryPoint>> socHistory = ValueNotifier(const []);
  final ValueNotifier<List<TelemetryPoint>> batteryPowerHistory = ValueNotifier(
    const [],
  );
  final ValueNotifier<List<TelemetryPoint>> activeLoadPowerHistory =
      ValueNotifier(const []);

  bool get isSystemStateLive =>
      !_disposed &&
      connectionStatus.value == MqttConnectionStatus.connected &&
      lastLiveSystemUpdate.value != null &&
      DateTime.now().difference(lastLiveSystemUpdate.value!) <
          AppConstants.staleDataThreshold;

  Stream<User?> get userChanges => authService.userChanges;

  Future<InstallationAccess> resolveCurrentAccess() =>
      _accessControlService.resolve(currentUser);

  /// Persists completion of the first-run setup workflow.
  Future<void> setSetupComplete(bool complete) =>
      _localState.setSetupComplete(complete);

  /// Persists a user-friendly node label on this device.
  Future<void> setNodeNameOverride(String mac, String name) =>
      _localState.setNodeNameOverride(mac, name);

  void _wireMqttSubscriptions() {
    connectionStatus.value = _mqtt.currentStatus;

    _subscriptions.add(
      _mqtt.connectionStatusStream.listen((status) {
        if (_disposed) return;
        connectionStatus.value = status;
      }),
    );
    _subscriptions.add(
      _mqtt.systemStateStream.listen((state) {
        if (_disposed) return;
        systemState.value = state;
        lastLiveSystemUpdate.value = DateTime.now();
        _appendHistoryPoint(socHistory, state.batterySocPercent);
        _appendHistoryPoint(batteryPowerHistory, state.batteryPowerW);
        _appendHistoryPoint(
          activeLoadPowerHistory,
          state.estimatedTotalLoadPowerW,
        );
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

  void _appendHistoryPoint(
    ValueNotifier<List<TelemetryPoint>> notifier,
    double? value,
  ) {
    if (_disposed || value == null || !value.isFinite) return;

    final now = DateTime.now();
    final next = [...notifier.value];
    if (next.isNotEmpty &&
        now.difference(next.last.timestamp) < _historySampleInterval) {
      next[next.length - 1] = TelemetryPoint(timestamp: now, value: value);
    } else {
      next.add(TelemetryPoint(timestamp: now, value: value));
    }

    notifier.value = _compactHistory(next, now);
    _scheduleHistoryPersist();
  }

  List<TelemetryPoint> _compactHistory(
    List<TelemetryPoint> input,
    DateTime now,
  ) {
    final cutoff = now.subtract(_historyRetention);
    final retained = input
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

  void _scheduleHistoryPersist() {
    if (_disposed || (_historyPersistTimer?.isActive ?? false)) return;
    _historyPersistTimer = Timer(
      _historyPersistDelay,
      () => unawaited(_persistTelemetryHistory()),
    );
  }

  Future<void> _persistTelemetryHistory() async {
    if (_disposed) return;
    final socSnapshot = List<TelemetryPoint>.of(socHistory.value);
    final batterySnapshot = List<TelemetryPoint>.of(batteryPowerHistory.value);
    final loadSnapshot = List<TelemetryPoint>.of(activeLoadPowerHistory.value);
    await Future.wait([
      _localState.cacheSocHistory(socSnapshot),
      _localState.cacheBatteryPowerHistory(batterySnapshot),
      _localState.cacheActiveLoadPowerHistory(loadSnapshot),
    ]);
  }

  Future<void> _loadCachedSnapshot() async {
    if (_disposed) return;

    if (systemState.value == null) {
      final cached = await _localState.readCachedSystemState();
      if (_disposed) return;
      if (cached != null && systemState.value == null) {
        systemState.value = SystemStateModel.fromJson(cached);
      }
    }

    final cachedAlerts = await _localState.readCachedAlerts();
    if (_disposed) return;
    if (cachedAlerts != null && alerts.value.isEmpty) {
      alerts.value = cachedAlerts.map(AlertModel.fromJson).toList();
    }

    final histories = await Future.wait<List<TelemetryPoint>>([
      _localState.readSocHistory(),
      _localState.readBatteryPowerHistory(),
      _localState.readActiveLoadPowerHistory(),
    ]);
    if (_disposed) return;

    socHistory.value = _mergeHistory(histories[0], socHistory.value);
    batteryPowerHistory.value = _mergeHistory(
      histories[1],
      batteryPowerHistory.value,
    );
    activeLoadPowerHistory.value = _mergeHistory(
      histories[2],
      activeLoadPowerHistory.value,
    );
  }

  Future<void> _persistAlerts() =>
      _localState.cacheAlerts(alerts.value.map((a) => a.toJson()).toList());

  Future<void> connectMqtt() => _mqtt.connect();
  MqttConfig get mqttConfig => _mqtt.currentConfig;
  Future<MqttConfig> loadMqttConfig() => _mqtt.loadMqttConfig();
  Future<MqttConnectionStatus> testMqttConnection(MqttConfig config) =>
      _mqtt.testConnection(config);
  Future<void> saveMqttConfig(MqttConfig config) =>
      _mqtt.saveAndConnect(config);

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

  Future<int?> readLastInstallerOptimizerIntervalSeconds() =>
      _localState.readInstallerOptimizerIntervalSeconds();

  Future<void> cacheLastInstallerOptimizerIntervalSeconds(int seconds) =>
      _localState.cacheInstallerOptimizerIntervalSeconds(seconds);

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
      _localState.readInstallerSafetyConfig();

  Future<void> cacheLastInstallerSafetyConfig(Map<String, dynamic> values) =>
      _localState.cacheInstallerSafetyConfig(values);

  Future<Map<String, dynamic>?> readLastInstallerBatteryConfig() =>
      _localState.readInstallerBatteryConfig();

  Future<void> cacheLastInstallerBatteryConfig(Map<String, dynamic> values) =>
      _localState.cacheInstallerBatteryConfig(values);

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

  Future<void> assignRole({
    required String email,
    required String role,
    String? installationId,
  }) => _accessControlService.assignRole(
    email: email,
    role: role,
    installationId: installationId,
  );

  Future<void> revokeAccess(String email) =>
      _accessControlService.revokeAccess(email);

  Future<void> acknowledgeAlert(String id) async {
    if (_disposed) return;
    alerts.value = [
      for (final alert in alerts.value)
        if (alert.id == id) alert.copyWith(acknowledged: true) else alert,
    ];
    await _persistAlerts();
  }

  Future<void> acknowledgeAllAlerts() async {
    if (_disposed) return;
    alerts.value = [
      for (final alert in alerts.value) alert.copyWith(acknowledged: true),
    ];
    await _persistAlerts();
  }

  User? get currentUser => authService.currentUser;

  Future<void> signOut() async {
    await _mqtt.disconnect();
    await authService.signOut();
  }

  void dispose() {
    if (_disposed) return;

    final socSnapshot = List<TelemetryPoint>.of(socHistory.value);
    final batterySnapshot = List<TelemetryPoint>.of(batteryPowerHistory.value);
    final loadSnapshot = List<TelemetryPoint>.of(activeLoadPowerHistory.value);

    _disposed = true;
    _historyPersistTimer?.cancel();
    unawaited(
      Future.wait([
        _localState.cacheSocHistory(socSnapshot),
        _localState.cacheBatteryPowerHistory(batterySnapshot),
        _localState.cacheActiveLoadPowerHistory(loadSnapshot),
      ]),
    );

    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    connectionStatus.dispose();
    systemState.dispose();
    lastLiveSystemUpdate.dispose();
    topology.dispose();
    loads.dispose();
    alerts.dispose();
    installerNodes.dispose();
    socHistory.dispose();
    batteryPowerHistory.dispose();
    activeLoadPowerHistory.dispose();
  }
}
