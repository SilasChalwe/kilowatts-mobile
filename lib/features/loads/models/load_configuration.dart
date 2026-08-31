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

  Map<String, dynamic> toCommandPayload() => {
    'nodeMac': nodeMac,
    'load': {
      'name': name,
      'relayPin': relayPin,
      'relayActiveHigh': relayActiveHigh,
      'mode': mode == LoadMode.fixed ? 'FIXED_OFF' : 'AUTO_OFF',
      'powerType': powerType.wireValue,
      'priority': priority,
      'powerRatingWatts': powerRatingWatts,
      'schedule': schedule.toWireJson(),
    },
  };
}
