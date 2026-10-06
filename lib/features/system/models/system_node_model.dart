import '../../../core/utils/json_parsing.dart';

/// Physical node identity and relay capabilities published on `state/nodes`.
class SystemNodeModel {
  const SystemNodeModel({
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

  factory SystemNodeModel.fromJson(Map<String, dynamic> json) {
    final rawPins = json['availableRelayPins'];
    return SystemNodeModel(
      mac: json.stringOrNull('mac') ?? '',
      role: (json.stringOrNull('role') ?? 'UNKNOWN').toUpperCase(),
      lifecycleState: (json.stringOrNull('lifecycleState') ?? 'UNKNOWN')
          .toUpperCase(),
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
