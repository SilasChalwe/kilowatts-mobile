/// Kilowatts v1 MQTT topic contract.
///
/// These are the namespaces the Central Node firmware currently publishes
/// and subscribes to. Field names inside each payload are treated
/// defensively (see `core/utils/json_parsing.dart`) since the firmware
/// contract is still evolving.
abstract final class MqttTopics {
  static const String stateSystem = 'kilowatts/v1/state/system';
  static const String stateTree = 'kilowatts/v1/state/tree';
  static const String stateLoads = 'kilowatts/v1/state/loads';
  static const String events = 'kilowatts/v1/events';
  static const String commandsLoad = 'kilowatts/v1/commands/load';
  static const String commandsSystem = 'kilowatts/v1/commands/system';
  static const String acks = 'kilowatts/v1/acks';

  static const List<String> subscriptions = [
    stateSystem,
    stateTree,
    stateLoads,
    events,
    acks,
  ];
}

abstract final class AppConstants {
  /// Retained state older than this is shown as stale rather than live.
  static const Duration staleDataThreshold = Duration(minutes: 2);

  /// How long a load/system command waits for a broker ack before it is
  /// reported as failed to the UI.
  static const Duration commandAckTimeout = Duration(seconds: 10);

  static const Duration mqttReconnectMinDelay = Duration(seconds: 2);
  static const Duration mqttReconnectMaxDelay = Duration(seconds: 30);

  static const int setupTotalSteps = 7;

  static const String appVersion = '1.0.0';

  /// Static UI thresholds for battery-charge coloring, matching firmware's
  /// real compile-time defaults (`CentralNodeConfig::WARNING_STATE_OF_CHARGE_PERCENT`
  /// / `MINIMUM_STATE_OF_CHARGE_PERCENT`). Not a live reading — firmware does
  /// not yet publish a `config/system` topic with the installation's actual
  /// configured values, so these are a reasonable static fallback only.
  static const double defaultLowBatteryWarningPercent = 40;
  static const double defaultLowBatteryCutoffPercent = 20;
}
