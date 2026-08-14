import '../../../core/utils/json_parsing.dart';

/// FIXED: the user's requested ON/OFF state is authoritative, subject to
/// critical safety protection.
/// AUTO: Best-First Search planning decides the target state each cycle.
///
/// Firmware's wire `mode` also encodes the ON/OFF bit (FIXED_ON/FIXED_OFF/
/// AUTO_ON/AUTO_OFF) — that bit is carried separately here as `targetOn`,
/// matching how the rest of this model already separates configured mode
/// from planning/confirmed state.
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

/// Mirrors firmware's `LoadHealth` exactly — whether Central currently
/// trusts this Load enough to accept new commands / plan around it.
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

/// UI-only importance bucket for the raw 0-10 wire priority (firmware has
/// no notion of "levels" — see `Load::priority_` / W_max in firmware). This
/// exists purely to keep a three-way selector in the UI; the wire value
/// sent/received is always the plain integer.
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

  /// Representative wire value sent when the user picks this level.
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

/// Why an Auto load's planner target is currently OFF, translated from
/// firmware's `rejectionReason` string (`TopologyTree::rejectionReasonText`)
/// into homeowner-facing language at the model boundary — screens should
/// never see the raw wire string. `null` means nothing is being rejected
/// (firmware's "NONE").
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

/// Firmware's actual schedule shape: a single preferred time-of-day, not a
/// start/end window. Meaning is "not eligible before this time" — it never
/// forces a load ON, and a disabled schedule imposes no deferment at all.
class LoadSchedule {
  const LoadSchedule({this.enabled = false, this.hour, this.minute});

  final bool enabled;
  final int? hour;
  final int? minute;

  static const disabled = LoadSchedule(enabled: false);
}

/// A controllable appliance/circuit endpoint. Identity is the owning
/// Node's MAC plus its relay pin — never the Node MAC alone, since the same
/// relay pin number can repeat on a different Smart Node.
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
    this.plannedPowerW,
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

  /// Raw firmware priority, 0-10 (higher = more important). See
  /// [LoadPriorityLevel] for the UI-only bucketed view.
  final int priority;

  /// The current Best-First planning decision (`targetOn` on the wire) for
  /// Auto loads, or the configured requested state for Fixed loads. Distinct
  /// from [confirmedState] — this is what Central *wants*, not necessarily
  /// what the relay has confirmed.
  final bool? requestedState;

  /// The last relay state confirmed back from the Central/Smart Node.
  final bool? confirmedState;

  /// Whether [confirmedState] is trustworthy right now. Firmware never
  /// forces this false on a failed command — only a successful hardware
  /// read-back sets it true — so screens must treat a stale/invalid
  /// confirmation as "unconfirmed", not silently trust it.
  final bool confirmedStateValid;

  final LoadHealth health;
  final LoadSchedule schedule;
  final LoadRejectionReason? rejectionReason;
  /// Installer-rated planning value (V × A), never a live per-load reading.
  final double? plannedPowerW;
  final double? ratedVoltageV;
  final double? ratedCurrentA;
  final double? startupPowerW;

  /// When this snapshot was parsed locally — firmware does not publish a
  /// per-load timestamp, so this is receipt time, not a device clock value.
  final DateTime? lastUpdated;

  String get id => '$owningNodeMac:$relayPin';

  bool get available => health == LoadHealth.available;

  /// The state actually being shown to the user right now, independent of
  /// how it got there (confirmed relay feedback if we have it, otherwise
  /// the best available signal).
  bool? get displayState => confirmedState ?? requestedState;

  factory LoadModel.fromJson(Map<String, dynamic> json) {
    final owningNodeMac = json.stringOrNull('nodeMac') ?? '';
    final relayPin = json.intOrNull('relayPin') ?? -1;
    return LoadModel(
      owningNodeMac: owningNodeMac,
      relayPin: relayPin,
      name: json.stringOrNull('name') ?? 'Load $relayPin',
      mode: LoadMode.fromWire(json.stringOrNull('mode')),
      priority: json.intOrNull('priority') ?? 0,
      requestedState: json.boolOrNull('targetOn'),
      confirmedState: json.boolOrNull('confirmedOn'),
      confirmedStateValid: json.boolOrNull('confirmedStateValid') ?? false,
      health: LoadHealth.fromWire(json.stringOrNull('health')),
      schedule: LoadSchedule(
        enabled: json.boolOrNull('scheduleEnabled') ?? false,
        hour: json.intOrNull('scheduleHour'),
        minute: json.intOrNull('scheduleMinute'),
      ),
      rejectionReason: LoadRejectionReason.fromWire(
        json.stringOrNull('rejectionReason'),
      ),
      plannedPowerW: json.doubleOrNull('nominalPowerWatts'),
      ratedVoltageV: json.doubleOrNull('nominalVoltageVolts'),
      ratedCurrentA: json.doubleOrNull('nominalCurrentAmps'),
      startupPowerW: json.doubleOrNull('startupWatts'),
      lastUpdated: DateTime.now(),
    );
  }
}
