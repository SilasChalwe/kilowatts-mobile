/// Kilowatts v1 MQTT topic contract.
///
/// These are the namespaces the Central Node firmware currently publishes
/// and subscribes to. Field names inside each payload are treated
/// defensively (see `core/utils/json_parsing.dart`) since the firmware
/// contract is still evolving.
class MqttTopics {
  const MqttTopics(this.namespace);

  final String namespace;

  String get status => '$namespace/status';
  String get stateSystem => '$namespace/state/system';
  String get stateTree => '$namespace/state/tree';
  String get stateLoads => '$namespace/state/loads';
  String get stateNodes => '$namespace/state/nodes';
  String get events => '$namespace/events';
  String get alerts => '$namespace/alerts';
  String get commandsLoad => '$namespace/commands/load';
  String get commandsConfig => '$namespace/commands/config';
  String get commandsReserve => '$namespace/commands/reserve';
  String get acks => '$namespace/acks';

  List<String> get subscriptions => [
    status,
    stateSystem,
    stateTree,
    stateLoads,
    stateNodes,
    events,
    alerts,
    acks,
  ];
}

abstract final class AppConstants {
  /// Central refreshes availability on each publish cycle (five minutes by
  /// default). Three missed default cycles are treated as stale when the
  /// broker did not deliver an explicit Last-Will `offline` message.
  static const Duration deviceAvailabilityTimeout = Duration(minutes: 16);

  /// How long a load/system command waits for a broker ack before it is
  /// reported as failed to the UI.
  static const Duration commandAckTimeout = Duration(seconds: 10);

  static const Duration mqttReconnectMinDelay = Duration(seconds: 2);
  static const Duration mqttReconnectMaxDelay = Duration(seconds: 30);

  /// mqtt_client's own connectTimeoutPeriod is not actually enforced around
  /// the initial socket handshake in the versions this app has
  /// used — a broker that never completes the handshake leaves connect()
  /// awaiting forever. This bounds it at the call site instead.
  static const Duration mqttConnectTimeout = Duration(seconds: 15);

  static const String appVersion = '1.0.0';

  /// Static UI thresholds for battery-charge coloring, matching firmware's
  /// real compile-time defaults (`CentralNodeConfig::WARNING_STATE_OF_CHARGE_PERCENT`
  /// / `MINIMUM_STATE_OF_CHARGE_PERCENT`). Not a live reading — firmware does
  /// not yet publish a `config/system` topic with the installation's actual
  /// configured values; these constants are display thresholds only.
  static const double defaultLowBatteryWarningPercent = 40;
  static const double defaultLowBatteryCutoffPercent = 20;
}
