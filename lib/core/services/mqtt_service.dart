import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:mqtt_client/mqtt_client.dart';

import '../../features/admin/models/installer_node_model.dart';
import '../../features/alerts/models/alert_model.dart';
import '../../features/loads/models/load_model.dart';
import '../../features/setup/models/setup_session.dart';
import '../../features/system/models/system_state_model.dart';
import '../../features/system/models/topology_model.dart';
import '../constants/app_constants.dart';
import 'command_outcome.dart';
import 'local_state_service.dart';
import 'mqtt_client_adapter.dart';
import 'mqtt_config.dart';
import 'mqtt_credentials_store.dart';

enum MqttConnectionStatus {
  notConfigured,
  connecting,
  connected,
  disconnected,
  reconnecting,
  authenticationFailure,
  tlsFailure,
  networkFailure,
}

/// The single application MQTT boundary. Broker topics are subscribed to
/// once here and fanned out as parsed domain models; nothing outside this
/// class talks to mqtt_client directly, decodes a topic payload, or holds
/// broker credentials. The Central Node is the only embedded MQTT client —
/// Smart Nodes never appear on the broker. This service talks only to the
/// Central Node's installation-scoped topic namespace.
///
/// Credentials come from [MqttCredentialsStore] (user-entered, on-device
/// only) rather than being configured at construction — [connect] loads
/// them lazily the first time it runs.
class MqttService {
  MqttService({
    MqttConfig? config,
    MqttCredentialsStore? credentialsStore,
    this.cache,
  }) : _config = config ?? const MqttConfig.unconfigured(),
       _credentialsStore = credentialsStore ?? MqttCredentialsStore();

  MqttConfig _config;
  final MqttCredentialsStore _credentialsStore;
  final LocalStateService? cache;

  MqttClient? _client;
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;
  bool _manualDisconnect = false;
  bool _credentialsLoaded = false;
  bool _disposed = false;
  StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>?
  _updatesSubscription;

  final _statusController = StreamController<MqttConnectionStatus>.broadcast();
  final _systemStateController = StreamController<SystemStateModel>.broadcast();
  final _topologyController = StreamController<TopologyModel>.broadcast();
  final _loadsController = StreamController<List<LoadModel>>.broadcast();
  final _alertController = StreamController<AlertModel>.broadcast();
  final _installerNodesController =
      StreamController<List<InstallerNodeModel>>.broadcast();

  final Map<String, Completer<CommandOutcome>> _pendingCommands = {};

  MqttConnectionStatus _status = MqttConnectionStatus.disconnected;
  MqttConnectionStatus get currentStatus => _status;
  MqttConfig get currentConfig => _config;

  Stream<MqttConnectionStatus> get connectionStatusStream =>
      _statusController.stream;
  Stream<SystemStateModel> get systemStateStream =>
      _systemStateController.stream;
  Stream<TopologyModel> get topologyStream => _topologyController.stream;
  Stream<List<LoadModel>> get loadsStream => _loadsController.stream;
  Stream<AlertModel> get alertStream => _alertController.stream;
  Stream<List<InstallerNodeModel>> get installerNodesStream =>
      _installerNodesController.stream;

  bool get isConfigured => _config.isConfigured;

  /// Reads the persisted connection once without opening a broker session.
  ///
  /// The web installer console needs this before it fills its connection
  /// form; otherwise a returning installer would see an empty form even
  /// though valid credentials were already stored on that device.
  Future<MqttConfig> loadMqttConfig() async {
    if (!_credentialsLoaded) {
      _credentialsLoaded = true;
      final saved = await _credentialsStore.read();
      if (saved != null) _config = saved;
    }
    return _config;
  }

  /// Connects using whatever credentials the user has already saved. The
  /// first call loads them from [MqttCredentialsStore]; if none have been
  /// entered yet, this reports [MqttConnectionStatus.notConfigured] instead
  /// of attempting a connection with empty credentials.
  Future<void> connect() async {
    if (_disposed ||
        (_status == MqttConnectionStatus.connected && _client != null)) {
      return;
    }
    _manualDisconnect = false;

    await loadMqttConfig();

    if (!_config.isConfigured) {
      _setStatus(MqttConnectionStatus.notConfigured);
      return;
    }

    await _attemptConnect();
  }

  /// Persists [config] as the active broker connection and (re)connects
  /// with it. Used by the MQTT Settings screen when the user saves what
  /// they typed in.
  Future<void> saveAndConnect(MqttConfig config) async {
    await _credentialsStore.save(config);
    _credentialsLoaded = true;
    _config = config;
    _manualDisconnect = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempt = 0;

    // A disconnect callback can arrive after a replacement client has been
    // created. Clear ownership before disconnecting so that the callback is
    // ignored as stale rather than scheduling a second, competing reconnect.
    final previousUpdates = _updatesSubscription;
    _updatesSubscription = null;
    if (previousUpdates != null) {
      unawaited(previousUpdates.cancel());
    }
    final previousClient = _client;
    _client = null;
    previousClient?.disconnect();
    await _attemptConnect();
  }

  /// Tries [config] on a short-lived, throwaway client without disturbing
  /// the main connection or any subscriptions — used by the "Test
  /// Connection" action before the user commits to saving it.
  Future<MqttConnectionStatus> testConnection(MqttConfig config) async {
    if (!config.isConfigured) return MqttConnectionStatus.notConfigured;

    final clientId =
        'kilowatts-mobile-test-${Random().nextInt(0xFFFFFFF).toRadixString(16)}';
    final client = _buildClient(config, clientId);

    try {
      final status = await client.connect(config.username, config.password);
      final connected = status?.state == MqttConnectionState.connected;
      client.disconnect();
      if (connected) return MqttConnectionStatus.connected;

      final isAuthFailure =
          status?.returnCode == MqttConnectReturnCode.badUsernameOrPassword ||
          status?.returnCode == MqttConnectReturnCode.notAuthorized ||
          status?.returnCode == MqttConnectReturnCode.identifierRejected;
      return isAuthFailure
          ? MqttConnectionStatus.authenticationFailure
          : MqttConnectionStatus.networkFailure;
    } catch (_) {
      return MqttConnectionStatus.networkFailure;
    }
  }

  MqttClient _buildClient(MqttConfig config, String clientId) =>
      buildPlatformMqttClient(config, clientId);

  Future<void> _attemptConnect() async {
    if (_disposed) return;
    _setStatus(MqttConnectionStatus.connecting);

    final clientId =
        'kilowatts-mobile-${Random().nextInt(0xFFFFFFF).toRadixString(16)}';
    final client = _buildClient(_config, clientId);
    client.onDisconnected = () => _handleDisconnected(client);

    _client = client;

    try {
      final status = await client.connect(_config.username, _config.password);

      // A save/reconnect can replace this client while connect() is still
      // awaiting a browser or TCP handshake. That older attempt must not
      // overwrite the newer connection's status or subscriptions.
      if (_disposed || !identical(_client, client)) {
        client.disconnect();
        return;
      }

      if (status?.state != MqttConnectionState.connected) {
        _client = null;
        client.disconnect();
        _handleConnectFailure(status?.returnCode);
        return;
      }

      _reconnectAttempt = 0;
      _setStatus(MqttConnectionStatus.connected);
      _subscribeToTopics(client);
      _updatesSubscription = client.updates?.listen(_handleIncomingMessages);
    } catch (_) {
      if (_disposed || !identical(_client, client)) return;
      _client = null;
      client.disconnect();
      _setStatus(MqttConnectionStatus.networkFailure);
      _scheduleReconnect();
    }
  }

  void _handleConnectFailure(MqttConnectReturnCode? returnCode) {
    final isAuthFailure =
        returnCode == MqttConnectReturnCode.badUsernameOrPassword ||
        returnCode == MqttConnectReturnCode.notAuthorized ||
        returnCode == MqttConnectReturnCode.identifierRejected;
    _setStatus(
      isAuthFailure
          ? MqttConnectionStatus.authenticationFailure
          : MqttConnectionStatus.networkFailure,
    );
    if (!isAuthFailure) {
      _scheduleReconnect();
    }
  }

  void _handleDisconnected(MqttClient disconnectedClient) {
    if (_disposed || !identical(_client, disconnectedClient)) return;

    final updates = _updatesSubscription;
    _updatesSubscription = null;
    if (updates != null) {
      unawaited(updates.cancel());
    }
    _client = null;
    if (_manualDisconnect) {
      _setStatus(MqttConnectionStatus.disconnected);
      return;
    }
    _setStatus(MqttConnectionStatus.disconnected);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_disposed || _manualDisconnect) return;
    _reconnectTimer?.cancel();
    _reconnectAttempt++;
    final delaySeconds = min(
      AppConstants.mqttReconnectMinDelay.inSeconds *
          (1 << min(_reconnectAttempt, 5)),
      AppConstants.mqttReconnectMaxDelay.inSeconds,
    );
    _setStatus(MqttConnectionStatus.reconnecting);
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), _attemptConnect);
  }

  MqttTopics get _topics => MqttTopics(_config.topicNamespace);

  void _subscribeToTopics(MqttClient client) {
    for (final topic in _topics.subscriptions) {
      client.subscribe(topic, MqttQos.atLeastOnce);
    }
  }

  void _handleIncomingMessages(
    List<MqttReceivedMessage<MqttMessage>> messages,
  ) {
    for (final received in messages) {
      final publish = received.payload;
      if (publish is! MqttPublishMessage) continue;

      final raw = MqttPublishPayload.bytesToStringAsString(
        publish.payload.message,
      );
      Map<String, dynamic> decoded;
      try {
        decoded = (jsonDecode(raw) as Map).cast<String, dynamic>();
      } catch (_) {
        continue;
      }

      _routeMessage(received.topic, decoded);
    }
  }

  void _routeMessage(String topic, Map<String, dynamic> payload) {
    if (topic == _topics.stateSystem) {
      final state = SystemStateModel.fromJson(payload);
      _systemStateController.add(state);
      cache?.cacheSystemState(payload);
      return;
    }
    if (topic == _topics.stateTree) {
      _topologyController.add(TopologyModel.fromJson(payload));
      return;
    }
    if (topic == _topics.stateLoads) {
      final loadsJson =
          (payload['loads'] as List?)
              ?.whereType<Map>()
              .map((e) => e.cast<String, dynamic>())
              .toList() ??
          const <Map<String, dynamic>>[];
      final loads = loadsJson.map(LoadModel.fromJson).toList();
      _loadsController.add(loads);
      cache?.cacheLoads(loadsJson);
      return;
    }
    if (topic == _topics.configNodes) {
      final nodes =
          (payload['nodes'] as List?)
              ?.whereType<Map>()
              .map((e) => e.cast<String, dynamic>())
              .map(InstallerNodeModel.fromJson)
              .toList(growable: false) ??
          const <InstallerNodeModel>[];
      _installerNodesController.add(nodes);
      return;
    }
    if (topic == _topics.events) {
      _alertController.add(AlertModel.fromJson(payload));
      return;
    }
    if (topic == _topics.acks) {
      _resolveAck(payload);
    }
  }

  void _resolveAck(Map<String, dynamic> payload) {
    final id = payload['commandId']?.toString();
    if (id == null) return;
    final completer = _pendingCommands[id];
    if (completer == null || completer.isCompleted) return;

    final status = payload['status']?.toString().toUpperCase();

    // Config commands travel in two phases. ACCEPTED means Central has
    // dispatched it, not that a remote Smart Node has actually changed
    // hardware. Wait for APPLIED or FAILED for the same command ID.
    if (status == 'ACCEPTED') return;

    _pendingCommands.remove(id);
    final accepted =
        status == 'APPLIED' || (status == null && payload['accepted'] == true);
    completer.complete(
      accepted
          ? CommandOutcome.confirmed(payload['reason']?.toString())
          : CommandOutcome.failed(
              payload['reason']?.toString() ?? 'Command rejected',
            ),
    );
  }

  /// Firmware parses `commandId` as a plain JSON number (`cJSON_IsNumber`),
  /// so this must never be sent as a quoted string.
  final Random _commandIdRandom = Random.secure();

  /// Command IDs are intentionally unpredictable rather than a per-app
  /// counter. Multiple phones and the installer portal can be connected at
  /// the same time, so a fresh app session must not accidentally accept a
  /// different client's acknowledgement with the same small counter value.
  int _nextCommandId() {
    var commandId = 0;
    do {
      commandId = _commandIdRandom.nextInt(0x7fffffff) + 1;
    } while (_pendingCommands.containsKey(commandId.toString()));
    return commandId;
  }

  Future<CommandOutcome> sendLoadCommand({
    required String nodeMac,
    required int relayPin,
    LoadMode? mode,
    bool? requestedState,
    int? priority,
    LoadSchedule? schedule,
  }) {
    final commandId = _nextCommandId();
    final payload = <String, dynamic>{
      'commandId': commandId,
      'nodeMac': nodeMac,
      'relayPin': relayPin,
      if (mode != null && requestedState != null)
        'mode': _wireMode(mode, requestedState),
      if (priority != null) 'priority': priority,
      if (schedule != null)
        'schedule': {
          'enabled': schedule.enabled,
          'hour': schedule.hour ?? 0,
          'minute': schedule.minute ?? 0,
        },
    };
    return _publishCommand(_topics.commandsLoad, commandId, payload);
  }

  String _wireMode(LoadMode mode, bool on) {
    if (mode == LoadMode.fixed) {
      return on ? 'FIXED_ON' : 'FIXED_OFF';
    }
    return on ? 'AUTO_ON' : 'AUTO_OFF';
  }

  /// Applies Central's persisted electrical safety policy. The caller only
  /// receives a confirmed outcome after the Central replies APPLIED.
  Future<CommandOutcome> sendSafetyConfig(SafetyConfigDraft draft) {
    final commandId = _nextCommandId();
    final payload = <String, dynamic>{
      'commandId': commandId,
      'action': 'APPLY_SAFETY_CONFIG',
      'safetyConfig': {
        'minimumStateOfChargePercent': draft.lowBatteryCutoffPercent,
        'warningStateOfChargePercent': draft.lowBatteryWarningPercent,
        'targetRuntimeHours': draft.targetRuntimeHours,
        'safetyFactor': 1 - (draft.safetyMarginPercent / 100),
        'maximumBatteryDischargeCurrentAmps': draft.maxBatteryDischargeCurrentA,
        'maximumMainCurrentAmps': draft.mainCurrentLimitA,
      },
    };
    return _publishCommand(_topics.commandsSystem, commandId, payload);
  }

  Future<CommandOutcome> commissionNode({
    required String nodeMac,
    required String friendlyName,
  }) {
    return _sendConfigCommand({
      'action': 'COMMISSION_NODE',
      'nodeMac': nodeMac,
      'friendlyName': friendlyName,
    });
  }

  Future<CommandOutcome> renameNode({
    required String nodeMac,
    required String friendlyName,
  }) {
    return _sendConfigCommand({
      'action': 'RENAME_NODE',
      'nodeMac': nodeMac,
      'friendlyName': friendlyName,
    });
  }

  /// Removes the Node from Central's authoritative installation record.
  /// A confirmed result means Central durably decommissioned it; the result
  /// message explains whether the best-effort Smart-Node reset notification
  /// could also be sent over ESP-NOW.
  Future<CommandOutcome> decommissionNode({required String nodeMac}) {
    return _sendConfigCommand({
      'action': 'DECOMMISSION_NODE',
      'nodeMac': nodeMac,
    });
  }

  Future<CommandOutcome> configureLoad(
    InstallerLoadConfiguration configuration,
  ) {
    return _sendConfigCommand({
      'action': 'CONFIGURE_LOAD',
      ...configuration.toCommandPayload(),
    });
  }

  Future<CommandOutcome> configureBatterySensor({
    required String centralNodeMac,
    required int i2cAddress,
    required double shuntResistanceOhms,
    required double maximumExpectedCurrentAmps,
    required double emaAlpha,
    required double batteryCapacityAmpHours,
    required double initialStateOfChargePercent,
  }) {
    return _sendConfigCommand({
      'action': 'CONFIGURE_BATTERY_SENSOR',
      'nodeMac': centralNodeMac,
      'batterySensor': {
        'i2cAddress': i2cAddress,
        'shuntResistanceOhms': shuntResistanceOhms,
        'maximumExpectedCurrentAmps': maximumExpectedCurrentAmps,
        'emaAlpha': emaAlpha,
        'batteryCapacityAmpHours': batteryCapacityAmpHours,
        'initialStateOfChargePercent': initialStateOfChargePercent,
      },
    });
  }

  Future<CommandOutcome> _sendConfigCommand(Map<String, dynamic> payload) {
    final commandId = _nextCommandId();
    return _publishCommand(_topics.commandsConfig, commandId, {
      'commandId': commandId,
      ...payload,
    });
  }

  Future<CommandOutcome> _publishCommand(
    String topic,
    int commandId,
    Map<String, dynamic> payload,
  ) {
    final client = _client;
    if (client == null || _status != MqttConnectionStatus.connected) {
      return Future.value(
        const CommandOutcome.failed('Not connected to the system'),
      );
    }

    final idKey = commandId.toString();
    final completer = Completer<CommandOutcome>();
    _pendingCommands[idKey] = completer;

    final builder = MqttClientPayloadBuilder()..addString(jsonEncode(payload));
    client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);

    return completer.future.timeout(
      AppConstants.commandAckTimeout,
      onTimeout: () {
        _pendingCommands.remove(idKey);
        return const CommandOutcome.failed('No response from the Central Node');
      },
    );
  }

  void _setStatus(MqttConnectionStatus status) {
    if (_disposed) return;
    _status = status;
    _statusController.add(status);
  }

  Future<void> disconnect() async {
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    final updates = _updatesSubscription;
    _updatesSubscription = null;
    if (updates != null) {
      await updates.cancel();
    }
    final client = _client;
    _client = null;
    client?.disconnect();
    _setStatus(MqttConnectionStatus.disconnected);
  }

  void dispose() {
    _disposed = true;
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    final updates = _updatesSubscription;
    _updatesSubscription = null;
    if (updates != null) {
      unawaited(updates.cancel());
    }
    final client = _client;
    _client = null;
    client?.disconnect();
    _statusController.close();
    _systemStateController.close();
    _topologyController.close();
    _loadsController.close();
    _alertController.close();
    _installerNodesController.close();
  }
}
