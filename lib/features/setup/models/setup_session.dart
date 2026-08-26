import '../../loads/models/load_model.dart';

/// Draft installation power policy.
///
/// The current firmware persists the minimum SoC, required runtime, maximum
/// battery discharge current and maximum main current through
/// CONFIGURE_POWER_LIMITS. Warning SoC and UI safety margin remain local UI
/// guidance because the current firmware command model does not persist them.
class SafetyConfigDraft {
  SafetyConfigDraft({
    this.lowBatteryCutoffPercent = 20,
    this.lowBatteryWarningPercent = 40,
    this.targetRuntimeHours = 4,
    this.safetyMarginPercent = 10,
    this.maxBatteryDischargeCurrentA = 40,
    this.mainCurrentLimitA = 30,
  });

  double lowBatteryCutoffPercent;
  double lowBatteryWarningPercent;
  double targetRuntimeHours;
  double safetyMarginPercent;
  double maxBatteryDischargeCurrentA;
  double mainCurrentLimitA;
}

/// Draft configuration for a single discovered Load, identified by owning
/// node MAC + relay pin.
class LoadConfigDraft {
  LoadConfigDraft({
    required this.owningNodeMac,
    required this.relayPin,
    required this.name,
    this.priority = 5,
    this.mode = LoadMode.auto,
    this.schedule = LoadSchedule.disabled,
  });

  final String owningNodeMac;
  final int relayPin;
  String name;
  int priority;
  LoadMode mode;
  LoadSchedule schedule;

  String get id => '$owningNodeMac:$relayPin';
}

class SetupSession {
  final Map<String, String> nodeNames = {};
  final Map<String, String> nodeLocations = {};
  final Map<String, LoadConfigDraft> loadDrafts = {};
  SafetyConfigDraft safety = SafetyConfigDraft();

  LoadConfigDraft draftFor(
    String owningNodeMac,
    int relayPin,
    String defaultName,
  ) {
    final key = '$owningNodeMac:$relayPin';
    return loadDrafts.putIfAbsent(
      key,
      () => LoadConfigDraft(
        owningNodeMac: owningNodeMac,
        relayPin: relayPin,
        name: defaultName,
      ),
    );
  }
}
