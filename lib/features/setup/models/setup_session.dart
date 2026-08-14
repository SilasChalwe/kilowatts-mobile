import '../../loads/models/load_model.dart';

/// Draft safety limits being built up across the Safety Configuration step.
/// Defaults mirror sensible homeowner-safe values. Firmware does not yet
/// accept a safety-config command (see [MqttService.sendSafetyConfig]'s own
/// doc comment) — submitting this draft is honestly rejected until it does.
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

/// Draft configuration for a single discovered Load, identified the same
/// way as [LoadModel]: owning node MAC + relay pin.
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

  /// Raw 0-10 wire priority (see [LoadPriorityLevel] for the UI bucketing).
  int priority;
  LoadMode mode;
  LoadSchedule schedule;

  String get id => '$owningNodeMac:$relayPin';
}

/// Mutable state accumulated while walking through the first-time setup
/// wizard. Held by [SystemConnectionScreen] and threaded by reference to
/// every subsequent step; nothing here is sent anywhere until the user
/// reaches Setup Summary and taps Finish.
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
