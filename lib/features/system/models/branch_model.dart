import '../../../core/utils/json_parsing.dart';

enum BranchStatus {
  healthy,
  warning,
  fault,
  unknown;

  /// Firmware has no wire-level branch status — derived client-side from
  /// the attached Load's relay health plus the installer-rated current
  /// estimate relative to the configured branch limit. An estimate can
  /// warn about an unsafe configuration, but cannot diagnose a live fault.
  static BranchStatus derive({
    required String? loadHealth,
    required double? utilization,
  }) {
    if (loadHealth == 'FAULTED') return BranchStatus.fault;
    if (utilization != null && utilization >= 1.0) return BranchStatus.warning;
    if (utilization != null && utilization >= 0.9) return BranchStatus.warning;
    if (loadHealth == null && utilization == null) return BranchStatus.unknown;
    return BranchStatus.healthy;
  }
}

/// An electrical branch — the physical circuit a relay switches. Distinct
/// from the Load attached to it: the branch is the wire and its current
/// limit, the Load is what the user is controlling. Matches
/// `TopologyTree::appendBranchesForNode`'s wire shape exactly.
class BranchModel {
  const BranchModel({
    required this.owningNodeMac,
    required this.relayPin,
    this.name,
    this.safeMaxCurrentA,
    this.safeMaxCurrentConfigured = false,
    this.estimatedCurrentA,
    this.status = BranchStatus.unknown,
    this.loadIds = const [],
  });

  final String owningNodeMac;
  final int relayPin;
  final String? name;
  final double? safeMaxCurrentA;

  /// Whether firmware actually has a reported `BranchConfiguration` for
  /// this relay pin yet, vs. a placeholder zero.
  final bool safeMaxCurrentConfigured;
  /// Derived from the installer-rated load current; not a live branch reading.
  final double? estimatedCurrentA;
  final BranchStatus status;
  final List<String> loadIds;

  String get id => '$owningNodeMac:$relayPin';

  double? get utilization {
    if (safeMaxCurrentA == null ||
        safeMaxCurrentA == 0 ||
        estimatedCurrentA == null) {
      return null;
    }
    return (estimatedCurrentA! / safeMaxCurrentA!).clamp(0, 1.5);
  }

  factory BranchModel.fromJson(Map<String, dynamic> json) {
    final nodeMac = json.stringOrNull('nodeMac') ?? '';
    final relayPin = json.intOrNull('relayPin') ?? -1;
    final load = json.mapOrNull('load');
    final estimatedCurrentA = load?.doubleOrNull('nominalCurrentAmps');
    final safeMaxCurrentA = json.doubleOrNull('maximumCurrentAmps');
    final double? utilization =
        (safeMaxCurrentA == null ||
            safeMaxCurrentA == 0 ||
            estimatedCurrentA == null)
        ? null
        : (estimatedCurrentA / safeMaxCurrentA).clamp(0, 1.5).toDouble();

    return BranchModel(
      owningNodeMac: nodeMac,
      relayPin: relayPin,
      name: load?.stringOrNull('name'),
      safeMaxCurrentA: safeMaxCurrentA,
      safeMaxCurrentConfigured:
          json.boolOrNull('maximumCurrentConfigured') ?? false,
      estimatedCurrentA: estimatedCurrentA,
      status: BranchStatus.derive(
        loadHealth: load?.stringOrNull('health'),
        utilization: utilization,
      ),
      loadIds: ['$nodeMac:$relayPin'],
    );
  }
}
