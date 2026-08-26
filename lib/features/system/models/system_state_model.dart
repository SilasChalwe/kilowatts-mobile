import '../../../core/utils/json_parsing.dart';

double? _sumOrNull(double? a, double? b) {
  if (a == null && b == null) return null;
  return (a ?? 0) + (b ?? 0);
}

/// Parsed payload of `kilowatts/v1/state/system` — the top-level battery
/// and power-budget snapshot, matching `SystemStateJson::build()` exactly
/// (nested `battery`/`power`/`connectivity`/`time`/`diagnostics` objects).
/// Every field is nullable; a field the firmware has not published yet must
/// render as "Unavailable", never a fabricated number.
///
/// Configured/physical safety limits (min SoC, current limits, etc.) are
/// not part of this payload — firmware does not yet publish a
/// `config/system` topic, so there is no live source for them. See
/// [SafetyConfigDraft] for the setup-wizard-only draft equivalent.
class SystemStateModel {
  const SystemStateModel({
    this.batterySocPercent,
    this.batteryVoltage,
    this.batteryCurrent,
    this.batterySensorConfigured,
    this.estimatedTotalLoadPowerW,
    this.availablePowerW,
    this.fixedLoadPowerW,
    this.autoLoadPowerW,
    this.remainingPowerW,
    this.committedPowerW,
    this.wifiConnected,
    this.wifiState,
    this.mqttConnected,
    this.timeValid,
    this.timeSource,
    this.lastOptimizationAt,
    this.sensorInputSource,
    this.operatingEnvironment,
    this.developmentSessionActive,
    this.faultCount,
    this.faultSummary,
    this.receivedAt,
  });

  final double? batterySocPercent;
  final double? batteryVoltage;
  final double? batteryCurrent;
  final bool? batterySensorConfigured;

  /// Conservative total derived from relay state and installer ratings.
  final double? estimatedTotalLoadPowerW;
  final double? availablePowerW;
  final double? fixedLoadPowerW;
  final double? autoLoadPowerW;
  final double? remainingPowerW;
  final double? committedPowerW;

  final bool? wifiConnected;
  final String? wifiState;
  final bool? mqttConnected;

  final bool? timeValid;
  final String? timeSource;

  /// Null when Central has not completed an optimisation cycle yet (wire
  /// value 0), not just when the field is missing.
  final DateTime? lastOptimizationAt;

  /// Firmware's `MeasurementSource` as text: "NONE", "HARDWARE" (real
  /// INA219) or "SIMULATED" (see `measurementSourceText` in
  /// src/central/namespace.h). Never presented ambiguously.
  final String? sensorInputSource;

  /// "PRODUCTION" or "DEVELOPMENT" — the whole device's Operating
  /// Environment, distinct from [sensorInputSource] (which is per-reading).
  /// A device stuck in DEVELOPMENT is serving simulated readings across the
  /// board, not just one overridden sensor, so this must be shown wherever
  /// [sensorInputSource] or any live number is shown, never inferred from it.
  final String? operatingEnvironment;

  /// True only while an explicit Development Session is armed on Central.
  final bool? developmentSessionActive;

  final int? faultCount;
  final String? faultSummary;

  /// When this snapshot was received locally — used to decide staleness,
  /// independent of any timestamp the payload itself may carry.
  final DateTime? receivedAt;

  double? get batteryPowerW {
    if (batteryVoltage == null || batteryCurrent == null) return null;
    return batteryVoltage! * batteryCurrent!;
  }

  static const empty = SystemStateModel();

  factory SystemStateModel.fromJson(Map<String, dynamic> json) {
    final battery = json.mapOrNull('battery') ?? const {};
    // Firmware (SystemStateJson::build) emits this object under the key
    // "powerFlow", not "power" — see lib/MqttManager/SystemStateJson.cpp.
    final power = json.mapOrNull('powerFlow') ?? const {};
    final connectivity = json.mapOrNull('connectivity') ?? const {};
    final time = json.mapOrNull('time') ?? const {};
    final diagnostics = json.mapOrNull('diagnostics') ?? const {};

    final lastOptimizationEpoch = time.intOrNull(
      'lastOptimizationEpochSeconds',
    );

    return SystemStateModel(
      batterySocPercent: battery.doubleOrNull('stateOfChargePercent'),
      batteryVoltage: battery.doubleOrNull('voltageVolts'),
      batteryCurrent: battery.doubleOrNull('currentAmps'),
      batterySensorConfigured: battery.boolOrNull('sensorConfigured'),
      // Firmware has no single "estimated total load power" field; the
      // closest equivalent is fixed + selected-auto power added together.
      estimatedTotalLoadPowerW: _sumOrNull(
        power.doubleOrNull('fixedOnPowerWatts'),
        power.doubleOrNull('selectedAutoLoadPowerWatts'),
      ),
      availablePowerW: power.doubleOrNull('automaticPowerBudgetWatts'),
      fixedLoadPowerW: power.doubleOrNull('fixedOnPowerWatts'),
      autoLoadPowerW: power.doubleOrNull('selectedAutoLoadPowerWatts'),
      remainingPowerW: power.doubleOrNull('remainingAutomaticBudgetWatts'),
      // Firmware does not publish a separate "committed power" field in
      // powerFlow; fixedOnPowerWatts is the FIXED_ON commitment.
      committedPowerW: power.doubleOrNull('fixedOnPowerWatts'),
      wifiConnected: connectivity.boolOrNull('wifiConnected'),
      wifiState: connectivity.stringOrNull('wifiState'),
      mqttConnected: connectivity.boolOrNull('mqttConnected'),
      timeValid: time.boolOrNull('valid'),
      timeSource: time.stringOrNull('source'),
      lastOptimizationAt:
          (lastOptimizationEpoch == null || lastOptimizationEpoch == 0)
          ? null
          : time.dateTimeOrNull('lastOptimizationEpochSeconds'),
      sensorInputSource: battery.stringOrNull('measurementSource'),
      // Firmware does not currently publish operatingEnvironment,
      // developmentSessionActive, faultCount or faultSummary anywhere
      // (see lib/MqttManager/SystemStateJson.cpp) — these remain null
      // until that is implemented. Do not treat their absence as false/0.
      operatingEnvironment: diagnostics.stringOrNull('operatingEnvironment'),
      developmentSessionActive: diagnostics.boolOrNull(
        'developmentSessionActive',
      ),
      faultCount: diagnostics.intOrNull('faultCount'),
      faultSummary: diagnostics.stringOrNull('faultSummary'),
      receivedAt: DateTime.now(),
    );
  }
}
