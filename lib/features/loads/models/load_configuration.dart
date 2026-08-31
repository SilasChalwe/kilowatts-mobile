import 'load_model.dart';

enum LoadPowerType {
  ac,
  dc;

  String get wireValue => this == LoadPowerType.ac ? 'AC' : 'DC';
}

class LoadConfiguration {
  const LoadConfiguration({
    required this.nodeMac,
    required this.name,
    required this.relayPin,
    required this.relayActiveHigh,
    required this.powerRatingWatts,
    required this.priority,
    required this.mode,
    this.powerType = LoadPowerType.dc,
    this.schedule = LoadSchedule.disabled,
  });

  final String nodeMac;
  final String name;
  final int relayPin;
  final bool relayActiveHigh;
  final double powerRatingWatts;
  final int priority;
  final LoadMode mode;
  final LoadPowerType powerType;
  final LoadSchedule schedule;

  /// Flat wire shape firmware's `handleLoadCommandMessage` requires for
  /// `action: "add"` (`ConfigCommandAction::CONFIGURE_LOAD` in
  /// `MqttManager.cpp`) — `nodeMac`/`relayPin` alongside `name`, `power`,
  /// `priority`, `mode`, `powerType`, `activeHigh` and `schedule` as
  /// top-level siblings, not nested under a `load` object.
  Map<String, dynamic> toCommandPayload() => {
    'nodeMac': nodeMac,
    'relayPin': relayPin,
    'name': name,
    'power': powerRatingWatts,
    'priority': priority,
    'mode': mode == LoadMode.fixed ? 'FIXED_OFF' : 'AUTO_OFF',
    'powerType': powerType.wireValue,
    'activeHigh': relayActiveHigh,
    'schedule': schedule.toWireJson(),
  };
}
