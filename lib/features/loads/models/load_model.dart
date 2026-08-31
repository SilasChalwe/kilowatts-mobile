import '../../../core/utils/json_parsing.dart';

/// FIXED: the user's requested ON/OFF state is authoritative, subject to
/// critical safety protection.
/// AUTO: Best-First Search planning decides the target state each cycle.
enum LoadMode {
  fixed,
  auto;

  static LoadMode fromWire(String? value) {
    switch (value) {
      case 'FIXED_ON':
      case 'FIXED_OFF':
        return LoadMode.fixed;
      case 'AUTO_ON':
      case 'AUTO_OFF':
      default:
        return LoadMode.auto;
    }
  }
}

/// Mirrors the older firmware health field when it is present. Current
/// `state/loads` payloads do not publish health, so the safe default is
/// available and command failures are still surfaced through MQTT ACKs.
enum LoadHealth {
  available,
  faulted,
  unavailable;

  static LoadHealth fromWire(String? value) {
    switch (value) {
      case 'FAULTED':
        return LoadHealth.faulted;
      case 'UNAVAILABLE':
        return LoadHealth.unavailable;
      case 'AVAILABLE':
      default:
        return LoadHealth.available;
    }
  }
}

/// UI-only importance bucket for the raw 0-10 wire priority.
enum LoadPriorityLevel {
  low,
  medium,
  high;

  String get label {
    switch (this) {
      case LoadPriorityLevel.low:
        return 'Low';
      case LoadPriorityLevel.medium:
        return 'Medium';
      case LoadPriorityLevel.high:
        return 'High';
    }
  }

  int get wireValue {
    switch (this) {
      case LoadPriorityLevel.low:
        return 2;
      case LoadPriorityLevel.medium:
        return 5;
      case LoadPriorityLevel.high:
        return 8;
    }
  }

  static LoadPriorityLevel bucketFor(int priority) {
    if (priority >= 7) return LoadPriorityLevel.high;
    if (priority >= 4) return LoadPriorityLevel.medium;
    return LoadPriorityLevel.low;
  }
}

/// Why an AUTO load is currently not selected by Best-First Search.
enum LoadRejectionReason {
  batteryReserveProtected,
  insufficientAvailablePower,
  batteryCurrentLimitReached,
  mainDistributionLimitReached,
  branchCurrentLimitReached,
  unknown;

  String get friendlyText {
    switch (this) {
      case LoadRejectionReason.batteryReserveProtected:
        return 'Battery reserve protected';
      case LoadRejectionReason.insufficientAvailablePower:
        return 'Not enough available power';
      case LoadRejectionReason.batteryCurrentLimitReached:
        return 'Battery current limit reached';
      case LoadRejectionReason.mainDistributionLimitReached:
        return 'Main distribution limit reached';
      case LoadRejectionReason.branchCurrentLimitReached:
        return 'Branch current limit reached';
      case LoadRejectionReason.unknown:
        return 'Deferred by system planning';
    }
  }

  static LoadRejectionReason? fromWire(String? value) {
    switch (value) {
      case null:
      case 'NONE':
        return null;
      case 'LOW_BATTERY':
        return LoadRejectionReason.batteryReserveProtected;
      case 'POWER_BUDGET_EXCEEDED':
        return LoadRejectionReason.insufficientAvailablePower;
      case 'BATTERY_CURRENT_LIMIT':
        return LoadRejectionReason.batteryCurrentLimitReached;
      case 'MAIN_LIMIT_EXCEEDED':
        return LoadRejectionReason.mainDistributionLimitReached;
      case 'BRANCH_LIMIT_EXCEEDED':
        return LoadRejectionReason.branchCurrentLimitReached;
      default:
        return LoadRejectionReason.unknown;
    }
  }
}

/// Preferred running window for an AUTO load.
///
/// This mirrors firmware `AutoSchedule` exactly: enabled schedules contain
/// startHour/startMinute/endHour/endMinute. Overnight windows are valid. The
/// legacy `hour`/`minute` parameters/getters are retained so older cached
/// state and UI call sites remain source-compatible while the app migrates.
class LoadSchedule {
  const LoadSchedule({
    this.enabled = false,
    int? startHour,
    int? startMinute,
    this.endHour,
    this.endMinute,
    int? hour,
    int? minute,
  }) : startHour = startHour ?? hour,
       startMinute = startMinute ?? minute;

  final bool enabled;
  final int? startHour;
  final int? startMinute;
  final int? endHour;
  final int? endMinute;

  int? get hour => startHour;
  int? get minute => startMinute;

  static const disabled = LoadSchedule(enabled: false);

  /// Exact JSON object accepted by firmware `MqttManager::parseSchedule`.
  Map<String, dynamic> toWireJson() {
    if (!enabled) return const {'enabled': false};

    final startH = (startHour ?? 0).clamp(0, 23).toInt();
    final startM = (startMinute ?? 0).clamp(0, 59).toInt();
    var endH = (endHour ?? ((startH + 1) % 24)).clamp(0, 23).toInt();
    final endM = (endMinute ?? startM).clamp(0, 59).toInt();

    // Firmware rejects a zero-length enabled window. If legacy data only
    // supplied one time, preserve its historical one-hour meaning.
    if (startH == endH && startM == endM) {
      endH = (startH + 1) % 24;
    }

    return {
      'enabled': true,
      'startHour': startH,
      'startMinute': startM,
      'endHour': endH,
      'endMinute': endM,
    };
  }
}

/// A controllable appliance/circuit endpoint. Identity is the owning Node's
/// MAC plus its relay pin.
class LoadModel {
  const LoadModel({
    required this.owningNodeMac,
    required this.relayPin,
    required this.name,
    required this.mode,
    required this.priority,
    this.owningNodeName,
    this.requestedState,
    this.confirmedState,
    this.confirmedStateValid = false,
    this.health = LoadHealth.available,
    this.schedule = LoadSchedule.disabled,
    this.rejectionReason,
    this.ratedPowerW,
    this.ratedVoltageV,
    this.ratedCurrentA,
    this.startupPowerW,
    this.lastUpdated,
  });

  final String owningNodeMac;
  final int relayPin;
  final String name;
  final String? owningNodeName;
  final LoadMode mode;
  final int priority;

  /// Current requested/planned state. Current firmware encodes this in the
  /// `mode` string itself (FIXED_ON/FIXED_OFF/AUTO_ON/AUTO_OFF), so the model
  /// derives it when the older `targetOn` field is absent.
  final bool? requestedState;

  /// Retained for compatibility with older firmware. Current firmware does
  /// not claim downstream relay/appliance confirmation, therefore this stays
  /// null/invalid unless an older payload explicitly provides it.
  final bool? confirmedState;
  final bool confirmedStateValid;

  final LoadHealth health;
  final LoadSchedule schedule;
  final LoadRejectionReason? rejectionReason;

  /// Installer-entered rated power. Current firmware publishes this as
  /// `powerRatingWatts`; it is not a live per-load measurement.
  final double? ratedPowerW;
  final double? ratedVoltageV;
  final double? ratedCurrentA;
  final double? startupPowerW;
  final DateTime? lastUpdated;

  String get id => '$owningNodeMac:$relayPin';
  bool get available => health == LoadHealth.available;
  bool? get displayState => confirmedState ?? requestedState;

  static bool? _stateFromMode(String? mode) {
    if (mode == null) return null;
    if (mode.endsWith('_ON')) return true;
    if (mode.endsWith('_OFF')) return false;
    return null;
  }

  factory LoadModel.fromJson(Map<String, dynamic> json) {
    final owningNodeMac = json.stringOrNull('nodeMac') ?? '';
    final relayPin = json.intOrNull('relayPin') ?? -1;
    final wireMode = json.stringOrNull('mode');
    final scheduleJson = json.mapOrNull('schedule') ?? const <String, dynamic>{};

    return LoadModel(
      owningNodeMac: owningNodeMac,
      relayPin: relayPin,
      name: json.stringOrNull('name') ?? 'Load $relayPin',
      owningNodeName: json.stringOrNull('nodeName'),
      mode: LoadMode.fromWire(wireMode),
      priority: json.intOrNull('priority') ?? 0,
      requestedState: json.boolOrNull('targetOn') ?? _stateFromMode(wireMode),
      confirmedState: json.boolOrNull('confirmedOn'),
      confirmedStateValid: json.boolOrNull('confirmedStateValid') ?? false,
      health: LoadHealth.fromWire(json.stringOrNull('health')),
      schedule: LoadSchedule(
        enabled:
            scheduleJson.boolOrNull('enabled') ??
            json.boolOrNull('scheduleEnabled') ??
            false,
        startHour:
            scheduleJson.intOrNull('startHour') ??
            scheduleJson.intOrNull('hour') ??
            json.intOrNull('scheduleHour'),
        startMinute:
            scheduleJson.intOrNull('startMinute') ??
            scheduleJson.intOrNull('minute') ??
            json.intOrNull('scheduleMinute'),
        endHour: scheduleJson.intOrNull('endHour'),
        endMinute: scheduleJson.intOrNull('endMinute'),
      ),
      rejectionReason: LoadRejectionReason.fromWire(
        json.stringOrNull('bestFirstRejectionReason') ??
            json.stringOrNull('rejectionReason'),
      ),
      ratedPowerW:
          json.doubleOrNull('powerRatingWatts') ??
          json.doubleOrNull('nominalPowerWatts'),
      ratedVoltageV: json.doubleOrNull('nominalVoltageVolts'),
      ratedCurrentA: json.doubleOrNull('nominalCurrentAmps'),
      startupPowerW: json.doubleOrNull('startupWatts'),
      lastUpdated: DateTime.now(),
    );
  }
}
