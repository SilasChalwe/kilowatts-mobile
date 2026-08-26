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
import '../services/command_outcome.dart' show CommandOutcome;
import '../services/local_state_service.dart';
import '../services/mqtt_config.dart';
import '../services/mqtt_service.dart';

export '../services/command_outcome.dart';
export '../services/mqtt_config.dart';
export '../services/mqtt_service.dart' show MqttConnectionStatus;

const _maxSessionSamples = 60;
const _maxStoredAlerts = 100;

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

  final ValueNotifier<List<double>> socSamples = ValueNotifier(const []);
  final ValueNotifier<List<double>> batteryPowerSamples = ValueNotifier(
    const [],
  );
  final ValueNotifier<List<double>> committedPowerSamples = ValueNotifier(
    const [],
  );

  bool get isSystemStateLive =>
      connectionStatus.value == MqttConnectionStatus.connected &&
      lastLiveSystemUpdate.value != null &&
      DateTime.now().difference(lastLiveSystemUpdate.value!) <
          AppConstants.staleDataThreshold;

  void _wireMqttSubscriptions() {
    connectionStatus.value = _mqtt.currentStatus;

    _subscriptions.add(
      _mqtt.connectionStatusStream.listen(
        (status) => connectionStatus.value = status,
      ),
    );
    _subscriptions.add(
      _mqtt.systemStateStream.listen((state) {
        systemState.value = state;
        lastLiveSystemUpdate.value = DateTime.now();
        _appendSample(socSamples, state.batterySocPercent);
        _appendSample(batteryPowerSamples, state.batteryPowerW);
        _appendSample(committedPowerSamples, state.committedPowerW);
      }),
    );
    _subscriptions.add(
      _mqtt.topologyStream.listen((value) => topology.value = value),
    );
    _subscriptions.add(
      _mqtt.loadsStream.listen((value) => loads.value = value),
    );
    _subscriptions.add(
      _mqtt.alertStream.listen((alert) {
        final next = <AlertModel>[alert, ...alerts.value];
        alerts.value = next.length > _maxStoredAlerts
            ? next.sublist(0, _maxStoredAlerts)
            : next;
        unawaited(_persistAlerts());
      }),
    );
    _subscriptions.add(
      _mqtt.installerNodesStream.listen((nodes) => installerNodes.value = nodes),
    );
  }

  void _appendSample(ValueNotifier<List<double>> notifier, double? value) {
    if (value == null) return;
    final next = [...notifier.value, value];
    notifier.value = next.length > _maxSessionSamples
        ? next.sublist(next.length - _maxSessionSamples)
        : next;
  }

  Future<void> _loadCachedSnapshot() async {
    if (systemState.value == null) {
      final cached = await _localState.readCachedSystemState();
      if (cached != null && systemState.value == null) {
        systemState.value = SystemStateModel.fromJson(cached);
      }
    }

    final cachedAlerts = await _localState.readCachedAlerts();
    if (cachedAlerts != null && alerts.value.isEmpty) {
      alerts.value = cachedAlerts.map(AlertModel.fromJson).toList();
    }
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

  void acknowledgeAllAlerts() {
    alerts.value = [
      for (final alert in alerts.value) alert.copyWith(acknowledged: true),
    ];
    unawaited(_persistAlerts());
  }

  Future<bool> isSetupComplete() => _localState.isSetupComplete();
  Future<void> setSetupComplete(bool value) =>
      _localState.setSetupComplete(value);
  Future<void> setNodeNameOverride(String mac, String name) =>
      _localState.setNodeNameOverride(mac, name);

  Stream<User?> get userChanges => authService.userChanges;
  User? get currentUser => authService.currentUser;
  Future<void> signOut() => authService.signOut();

  Future<InstallationAccess> resolveCurrentAccess() =>
      _accessControlService.resolve(currentUser);

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

  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _mqtt.dispose();
    connectionStatus.dispose();
    systemState.dispose();
    lastLiveSystemUpdate.dispose();
    topology.dispose();
    loads.dispose();
    alerts.dispose();
    installerNodes.dispose();
    socSamples.dispose();
    batteryPowerSamples.dispose();
    committedPowerSamples.dispose();
  }
}
