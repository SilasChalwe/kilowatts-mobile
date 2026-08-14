import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import '../../features/alerts/models/alert_model.dart';
import '../../features/loads/models/load_model.dart';
import '../../features/setup/models/setup_session.dart';
import '../../features/system/models/system_state_model.dart';
import '../../features/system/models/topology_model.dart';
import '../constants/app_constants.dart';
import 'command_outcome.dart';
import 'local_state_service.dart';
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
/// Smart Nodes never appear on the broker, so this service only ever needs
/// the six `kilowatts/v1/...` topics.
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

  MqttServerClient? _client;
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;
  bool _manualDisconnect = false;
  bool _credentialsLoaded = false;
  StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>?
  _updatesSubscription;

  final _statusController = StreamController<MqttConnectionStatus>.broadcast();
  final _systemStateController = StreamController<SystemStateModel>.broadcast();
  final _topologyController = StreamController<TopologyModel>.broadcast();
  final _loadsController = StreamController<List<LoadModel>>.broadcast();
  final _alertController = StreamController<AlertModel>.broadcast();

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

  bool get isConfigured => _config.isConfigured;

  /// Connects using whatever credentials the user has already saved. The
  /// first call loads them from [MqttCredentialsStore]; if none have been
  /// entered yet, this reports [MqttConnectionStatus.notConfigured] instead
  /// of attempting a connection with empty credentials.
  Future<void> connect() async {
    _manualDisconnect = false;

    if (!_config.isConfigured && !_credentialsLoaded) {
      _credentialsLoaded = true;
      final saved = await _credentialsStore.read();
      if (saved != null) _config = saved;
    }

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
    _reconnectAttempt = 0;
    _updatesSubscription?.cancel();
    _client?.disconnect();
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
    } on HandshakeException {
      return MqttConnectionStatus.tlsFailure;
    } catch (_) {
      return MqttConnectionStatus.networkFailure;
    }
  }

  MqttServerClient _buildClient(MqttConfig config, String clientId) {
    final client = MqttServerClient.withPort(
      config.host,
      clientId,
      config.port,
    );
    client.secure = config.useTls;
    client.keepAlivePeriod = 30;
    client.autoReconnect = false;
    client.setProtocolV311();
    client.connectionMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .startClean()
        .withWillQos(MqttQos.atMostOnce);
    return client;
  }

  Future<void> _attemptConnect() async {
    _setStatus(MqttConnectionStatus.connecting);

    final clientId =
        'kilowatts-mobile-${Random().nextInt(0xFFFFFFF).toRadixString(16)}';
    final client = _buildClient(_config, clientId);
    client.onDisconnected = _handleDisconnected;

    _client = client;

    try {
      final status = await client.connect(_config.username, _config.password);

      if (status?.state != MqttConnectionState.connected) {
        _handleConnectFailure(status?.returnCode);
        return;
      }

      _reconnectAttempt = 0;
      _setStatus(MqttConnectionStatus.connected);
      _subscribeToTopics(client);
      _updatesSubscription = client.updates?.listen(_handleIncomingMessages);
    } on HandshakeException {
      _setStatus(MqttConnectionStatus.tlsFailure);
      _scheduleReconnect();
    } on SocketException {
      _setStatus(MqttConnectionStatus.networkFailure);
      _scheduleReconnect();
    } catch (_) {
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

  void _handleDisconnected() {
    _updatesSubscription?.cancel();
    if (_manualDisconnect) {
      _setStatus(MqttConnectionStatus.disconnected);
      return;
    }
    _setStatus(MqttConnectionStatus.disconnected);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_manualDisconnect) return;
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

  void _subscribeToTopics(MqttServerClient client) {
    for (final topic in MqttTopics.subscriptions) {
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
    switch (topic) {
      case MqttTopics.stateSystem:
        final state = SystemStateModel.fromJson(payload);
        _systemStateController.add(state);
        cache?.cacheSystemState(payload);
      case MqttTopics.stateTree:
        _topologyController.add(TopologyModel.fromJson(payload));
      case MqttTopics.stateLoads:
        final loadsJson =
            (payload['loads'] as List?)
                ?.whereType<Map>()
                .map((e) => e.cast<String, dynamic>())
                .toList() ??
            const [];
        final loads = loadsJson.map(LoadModel.fromJson).toList();
        _loadsController.add(loads);
        cache?.cacheLoads(loadsJson);
      case MqttTopics.events:
        _alertController.add(AlertModel.fromJson(payload));
      case MqttTopics.acks:
        _resolveAck(payload);
    }
  }

  void _resolveAck(Map<String, dynamic> payload) {
    final id = payload['commandId']?.toString();
    if (id == null) return;
    final completer = _pendingCommands.remove(id);
    if (completer == null || completer.isCompleted) return;

    final accepted = payload['accepted'] == true;
    completer.complete(
      accepted
          ? const CommandOutcome.confirmed()
          : CommandOutcome.failed(
              payload['reason']?.toString() ?? 'Command rejected',
            ),
    );
  }

  /// Firmware parses `commandId` as a plain JSON number (`cJSON_IsNumber`),
  /// so this must never be sent as a quoted string. A monotonic counter is
  /// sufficient uniqueness for one app session's in-flight commands.
  int _commandIdCounter = 0;
  int _nextCommandId() => ++_commandIdCounter;

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
      'priority': ?priority,
      if (schedule != null)
        'schedule': {
          'enabled': schedule.enabled,
          'hour': schedule.hour ?? 0,
          'minute': schedule.minute ?? 0,
        },
    };
    return _publishCommand(MqttTopics.commandsLoad, commandId, payload);
  }

  String _wireMode(LoadMode mode, bool on) {
    if (mode == LoadMode.fixed) {
      return on ? 'FIXED_ON' : 'FIXED_OFF';
    }
    return on ? 'AUTO_ON' : 'AUTO_OFF';
  }

  /// Publishes to the documented `commands/system` topic as an
  /// `APPLY_SAFETY_CONFIG` action. Firmware does not currently recognise
  /// this action (only `REQUEST_OPTIMIZATION_CYCLE` exists today) — the
  /// broker will honestly reply with `accepted:false, reason:"unrecognised
  /// action"` until firmware adds support. This is left wired up (rather
  /// than removed) so the UI already works the moment firmware catches up;
  /// callers must not treat the returned [CommandOutcome] as proof the
  /// setting took effect.
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
    return _publishCommand(MqttTopics.commandsSystem, commandId, payload);
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
    _status = status;
    _statusController.add(status);
  }

  Future<void> disconnect() async {
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    _client?.disconnect();
  }

  void dispose() {
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    _updatesSubscription?.cancel();
    _client?.disconnect();
    _statusController.close();
    _systemStateController.close();
    _topologyController.close();
    _loadsController.close();
    _alertController.close();
  }
}
