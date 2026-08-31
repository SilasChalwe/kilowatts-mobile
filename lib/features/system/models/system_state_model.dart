import '../../../core/utils/json_parsing.dart';

double? _sumOrNull(double? a, double? b) {
  if (a == null && b == null) return null;
  return (a ?? 0) + (b ?? 0);
}

/// Parsed payload of `kilowatts/v1/state/system` — the top-level battery
/// and power-budget snapshot, matching `SystemStateJson::build()` exactly
/// (nested `battery`/`powerFlow`/`connectivity`/`time`/`diagnostics` objects).
/// Every field is nullable; a field the firmware has not published yet must
/// render as "Unavailable", never a fabricated number.
///
/// Configured/physical safety limits not present in this payload are never
/// fabricated by the application.
class SystemStateModel {
  const SystemStateModel({
    this.batterySocPercent,
    this.batteryVoltage,
    this.batteryCurrent,
    this.batterySensorConfigured,
    this.batteryCapacityAmpHours,
    this.batteryNominalVoltageV,
    this.batteryRatedEnergyWattHours,
    this.storedEnergyWattHours,
    this.usableEnergyWattHours,
    this.reserveConfigured,
    this.reserveSoCPercent,
    this.requiredRuntimeConfigured,
    this.requiredRuntimeHours,
    this.sustainablePowerW,
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

  /// The configured battery capacity (Ah), live from Central.
  final double? batteryCapacityAmpHours;

  /// The configured nameplate voltage (V) — distinct from
  /// [batteryVoltage], which is the live measured reading.
  final double? batteryNominalVoltageV;

  /// The battery's full energy capacity (`capacityAmpHours × nominalVoltageVolts`)
  /// at 100% charge — unaffected by current SoC or reserve. This is
  /// [batteryCapacityAmpHours] expressed as energy rather than a raw Ah
  /// rating.
  final double? batteryRatedEnergyWattHours;

  /// Total energy the battery currently holds, derived from its rated
  /// capacity and current state of charge — not reduced by the reserve.
  final double? storedEnergyWattHours;

  /// Energy above the configured reserve threshold — what the system can
  /// actually draw down to before battery protection engages.
  final double? usableEnergyWattHours;

  /// Whether power limits (and therefore a
  /// reserve threshold) at all yet. `reserveSoCPercent` is not meaningful
  /// when this is false.
  final bool? reserveConfigured;

  /// The currently configured battery reserve threshold (%). This is the
  /// only live source of that value and is controlled by the homeowner.
  final double? reserveSoCPercent;

  /// Whether a required-runtime target has been set at all
  /// (`requiredRuntimeHours` is 0/not meaningful when this is false).
  final bool? requiredRuntimeConfigured;

  /// The currently configured required-runtime target (hours), live from
  /// Central.
  final double? requiredRuntimeHours;

  final double? sustainablePowerW;

  /// Conservative total derived from relay state and configured ratings.
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
  /// INA219) or "SIMULATED". Never presented ambiguously.
  final String? sensorInputSource;

  /// Reserved for a future firmware field. Current production firmware does
  /// not publish the operating environment in `state/system`.
  final String? operatingEnvironment;

  /// Reserved for a future firmware field. Current production firmware does
  /// not publish development-session state in `state/system`.
  final bool? developmentSessionActive;

  /// Current firmware publishes this as diagnostics.pinCommandErrorCount.
  final int? faultCount;

  /// Reserved for a future firmware summary field.
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
    final power = json.mapOrNull('powerFlow') ?? const {};
    final connectivity = json.mapOrNull('connectivity') ?? const {};
    final time = json.mapOrNull('time') ?? const {};
    final diagnostics = json.mapOrNull('diagnostics') ?? const {};

    final lastOptimizationEpoch = time.intOrNull(
      'lastOptimizationEpochSeconds',
    );

    // powerFlow is only meaningful once Central has actually computed a
    // power budget (after its first successful optimization cycle, with
    // configuration + a fresh SoC reading). Before that, every numeric
    // field in the object is an unset 0, not a real reading — treat it as
    // absent rather than display a misleading zero. The current wire contract
    // requires an explicit validity flag.
    final powerFlowValid = power.boolOrNull('powerFlowValid') == true;
    double? validPower(String key) =>
        powerFlowValid ? power.doubleOrNull(key) : null;

    return SystemStateModel(
      batterySocPercent: battery.doubleOrNull('stateOfChargePercent'),
      batteryVoltage: battery.doubleOrNull('voltageVolts'),
      batteryCurrent: battery.doubleOrNull('currentAmps'),
      batterySensorConfigured: battery.boolOrNull('sensorConfigured'),
      batteryCapacityAmpHours: battery.doubleOrNull('capacityAmpHours'),
      batteryNominalVoltageV: battery.doubleOrNull('nominalVoltageVolts'),
      batteryRatedEnergyWattHours: battery.doubleOrNull('ratedEnergyWattHours'),
      storedEnergyWattHours: battery.doubleOrNull('storedEnergyWattHours'),
      usableEnergyWattHours: battery.doubleOrNull('usableEnergyWattHours'),
      reserveConfigured: battery.boolOrNull('reserveConfigured'),
      reserveSoCPercent: battery.doubleOrNull('reserveSoCPercent'),
      requiredRuntimeConfigured: battery.boolOrNull(
        'requiredRuntimeConfigured',
      ),
      requiredRuntimeHours: battery.doubleOrNull('requiredRuntimeHours'),
      sustainablePowerW: battery.doubleOrNull(
        'maximumPowerForRequiredRuntimeWatts',
      ),
      // Firmware has no single "estimated total load power" field; the
      // closest equivalent is fixed + selected-auto power added together.
      estimatedTotalLoadPowerW: powerFlowValid
          ? _sumOrNull(
              power.doubleOrNull('fixedOnPowerWatts'),
              power.doubleOrNull('selectedAutoLoadPowerWatts'),
            )
          : null,
      availablePowerW: validPower('automaticPowerBudgetWatts'),
      fixedLoadPowerW: validPower('fixedOnPowerWatts'),
      autoLoadPowerW: validPower('selectedAutoLoadPowerWatts'),
      remainingPowerW: validPower('remainingAutomaticBudgetWatts'),
      // Firmware does not publish a separate "committed power" field in
      // powerFlow; fixedOnPowerWatts is the FIXED_ON commitment.
      committedPowerW: validPower('fixedOnPowerWatts'),
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
      faultCount: diagnostics.intOrNull('pinCommandErrorCount'),
      faultSummary: diagnostics.stringOrNull('faultSummary'),
      receivedAt: DateTime.now(),
    );
  }
}
