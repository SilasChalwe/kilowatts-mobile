import '../../../core/utils/json_parsing.dart';
import '../../loads/models/load_model.dart';

/// The installer-facing identity/configuration view published on
/// `config/nodes`. It is intentionally distinct from the homeowner
/// topology model: it exposes hardware capabilities and commissioning
/// lifecycle, not just a friendly network tree.
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
  });

  final String mac;
  final String role;
  final String lifecycleState;
  final String syncState;
  final String? name;
  final String? firmwareVersion;
  final String? chipModel;

  /// A firmware-declared, board-safe GPIO inventory. The web UI must only
  /// offer pins in this list; it never guesses that a physical pin is safe.
  final List<int> availableRelayPins;

  bool get isSmartNode => role == 'SMART';
  bool get isCommissioned =>
      lifecycleState == 'COMMISSIONED' || lifecycleState == 'OPERATIONAL';
  bool get canBeCommissioned =>
      lifecycleState == 'UNCOMMISSIONED' || lifecycleState == 'DISCOVERED';

  String get displayName {
    final trimmed = name?.trim() ?? '';
    return trimmed.isEmpty ? mac : trimmed;
  }

  factory InstallerNodeModel.fromJson(Map<String, dynamic> json) {
    final rawPins = json['relayCapabilities'];
    return InstallerNodeModel(
      mac: json.stringOrNull('mac') ?? '',
      // Firmware emits lifecycle text in lowercase; normalize at the wire
      // boundary so a real discovered `smart` node is configurable here.
      role: (json.stringOrNull('role') ?? 'UNKNOWN').toUpperCase(),
      lifecycleState:
          (json.stringOrNull('lifecycleState') ?? 'UNKNOWN').toUpperCase(),
      syncState: (json.stringOrNull('syncState') ?? 'UNKNOWN').toUpperCase(),
      name: json.stringOrNull('name'),
      firmwareVersion: json.stringOrNull('firmwareVersion'),
      chipModel: json.stringOrNull('chipModel'),
      availableRelayPins: rawPins is List
          ? rawPins
                .map((value) => value is num ? value.toInt() : null)
                .whereType<int>()
                .toList(growable: false)
          : const [],
    );
  }
}

/// The exact physical and planning facts required to create one real load
/// channel on a commissioned Smart Node. Smart Nodes have no per-load
/// INA219: voltage/current are verified nameplate or commissioning-test
/// ratings, used to derive a conservative planning estimate rather than a
/// live consumption reading.
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
  final LoadSchedule schedule;

  Map<String, dynamic> toCommandPayload() => {
    'nodeMac': nodeMac,
    'load': {
      'name': name,
      'relayPin': relayPin,
      'relayActiveHigh': relayActiveHigh,
      'nominalVoltageVolts': nominalVoltageVolts,
      'nominalCurrentAmps': nominalCurrentAmps,
      'branchMaximumCurrentAmps': branchMaximumCurrentAmps,
      'startupWatts': startupWatts,
      'priority': priority,
      'mode': _wireMode(mode),
      'schedule': {
        'enabled': schedule.enabled,
        'hour': schedule.hour ?? 0,
        'minute': schedule.minute ?? 0,
      },
    },
  };

  String _wireMode(LoadMode value) =>
      value == LoadMode.fixed ? 'FIXED_OFF' : 'AUTO_OFF';
}
