import '../../../core/utils/json_parsing.dart';

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

  /// "DEVELOPMENT" or "INA219 HARDWARE" — never presented ambiguously.
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
    final power = json.mapOrNull('power') ?? const {};
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
      estimatedTotalLoadPowerW: power.doubleOrNull(
        'estimatedTotalLoadPowerWatts',
      ),
      availablePowerW: power.doubleOrNull('availablePowerWatts'),
      fixedLoadPowerW: power.doubleOrNull('fixedOnRunningPowerWatts'),
      autoLoadPowerW: power.doubleOrNull('powerAvailableForAutoLoadsWatts'),
      remainingPowerW: power.doubleOrNull('remainingPowerWatts'),
      committedPowerW: power.doubleOrNull('committedPowerWatts'),
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
