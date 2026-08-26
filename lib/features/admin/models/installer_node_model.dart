import '../../../core/utils/json_parsing.dart';
import '../../loads/models/load_model.dart';

/// The installer-facing identity/configuration view published on
/// `state/nodes`.
class InstallerNodeModel {
  const InstallerNodeModel({
    required this.mac,
    required this.role,
    required this.lifecycleState,
    required this.syncState,
    this.name,
    this.firmwareVersion,
    this.chipModel,
    this.availableRelayPins = const [],
    this.online,
    this.hopCountToCentral,
    this.nextHopMac,
    this.lastSeenMillisecondsSinceBoot,
  });

  final String mac;
  final String role;
  final String lifecycleState;
  final String syncState;
  final String? name;
  final String? firmwareVersion;
  final String? chipModel;
  final List<int> availableRelayPins;
  final bool? online;
  final int? hopCountToCentral;
  final String? nextHopMac;
  final int? lastSeenMillisecondsSinceBoot;

  bool get isSmartNode => role == 'SMART';
  bool get isCentralNode => role == 'CENTRAL';
  bool get isCommissioned =>
      lifecycleState == 'COMMISSIONED' || lifecycleState == 'OPERATIONAL';
  bool get canBeCommissioned =>
      lifecycleState == 'UNCOMMISSIONED' || lifecycleState == 'DISCOVERED';

  String get displayName {
    final trimmed = name?.trim() ?? '';
    return trimmed.isEmpty ? mac : trimmed;
  }

  factory InstallerNodeModel.fromJson(Map<String, dynamic> json) {
    final rawPins = json['availableRelayPins'];
    return InstallerNodeModel(
      mac: json.stringOrNull('mac') ?? '',
      role: (json.stringOrNull('role') ?? 'UNKNOWN').toUpperCase(),
      lifecycleState:
          (json.stringOrNull('lifecycleState') ?? 'UNKNOWN').toUpperCase(),
      syncState: (json.stringOrNull('syncState') ?? 'UNKNOWN').toUpperCase(),
      name: json.stringOrNull('nodeName'),
      firmwareVersion: json.stringOrNull('firmwareVersion'),
      chipModel: json.stringOrNull('chipModel'),
      availableRelayPins: rawPins is List
          ? rawPins
                .map((value) => value is num ? value.toInt() : null)
                .whereType<int>()
                .toList(growable: false)
          : const [],
      online: json.boolOrNull('online'),
      hopCountToCentral: json.intOrNull('hopCountToCentral'),
      nextHopMac: json.stringOrNull('nextHopMac'),
      lastSeenMillisecondsSinceBoot: json.intOrNull('lastSeenMilliseconds'),
    );
  }
}

enum InstallerLoadPowerType {
  ac,
  dc;

  String get wireValue => this == InstallerLoadPowerType.ac ? 'AC' : 'DC';
}

/// Physical/planning facts required by firmware CONFIGURE_LOAD.
///
/// Existing installer forms still collect nameplate voltage/current because
/// those values are useful during commissioning. The MQTT contract itself
/// receives the resulting `powerRatingWatts`, plus AC/DC power type, relay
/// polarity, priority, mode and schedule.
class InstallerLoadConfiguration {
  const InstallerLoadConfiguration({
    required this.nodeMac,
    required this.name,
    required this.relayPin,
    required this.relayActiveHigh,
    required this.nominalVoltageVolts,
    required this.nominalCurrentAmps,
    required this.branchMaximumCurrentAmps,
    required this.startupWatts,
    required this.priority,
    required this.mode,
    this.powerType = InstallerLoadPowerType.dc,
    this.schedule = LoadSchedule.disabled,
  });

  final String nodeMac;
  final String name;
  final int relayPin;
  final bool relayActiveHigh;
  final double nominalVoltageVolts;
  final double nominalCurrentAmps;
  final double branchMaximumCurrentAmps;
  final double startupWatts;
  final int priority;
  final LoadMode mode;
  final InstallerLoadPowerType powerType;
  final LoadSchedule schedule;

  double get powerRatingWatts => nominalVoltageVolts * nominalCurrentAmps;

  Map<String, dynamic> toCommandPayload() => {
    'nodeMac': nodeMac,
    'load': {
      'name': name,
      'relayPin': relayPin,
      'relayActiveHigh': relayActiveHigh,
      'mode': _wireMode(mode),
      'powerType': powerType.wireValue,
      'priority': priority,
      'powerRatingWatts': powerRatingWatts,
      'schedule': schedule.toWireJson(),
    },
  };

  String _wireMode(LoadMode value) =>
      value == LoadMode.fixed ? 'FIXED_OFF' : 'AUTO_OFF';
}
