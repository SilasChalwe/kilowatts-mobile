import '../../../core/utils/json_parsing.dart';

/// Parsed payload of `state.system` inside the combined `kilowatts/v1/state`
/// message, matching `SystemStateJson::build()` exactly (nested `battery`
/// and `powerFlow` objects, `lastOptimizationEpochSeconds` at the top
/// level) — verified field-for-field against a live broker capture, not
/// inferred from documentation. Every field is nullable; a field the
/// firmware has not published must render as "Unavailable", never a
/// fabricated number.
///
/// Firmware does not currently publish Wi-Fi/MQTT connectivity or a
/// `time`/`diagnostics` block at the system level (per-node diagnostics live
/// under `state.nodes`, see `NodeDiagnosticsModel`) — those fields stay null
/// here until a firmware change adds them, not because of a parsing bug.
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
    this.stateOfChargeValid,
    this.stateOfChargeSource,
    this.batteryReserveReached,
    this.requiredRuntimeConfigured,
    this.requiredRuntimeHours,
    this.remainingRuntimeHours,
    this.estimatedRuntimeHours,
    this.runtimeEstimateValid,
    this.requiredRuntimeAchievable,
    this.powerBudgetWatts,
    this.powerReserveWatts,
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

  /// Energy above the configured minimum-SoC threshold — what the system
  /// can actually draw down to before load shedding protects the battery.
  final double? usableEnergyWattHours;

  /// Whether the current [batterySocPercent] comes from a trustworthy
  /// source (coulomb counting once a real/simulated measurement stream is
  /// established), distinct from whether a value is merely present.
  final bool? stateOfChargeValid;

  /// Firmware's `stateOfChargeSource`, e.g. `"COULOMB_COUNTING"`.
  final String? stateOfChargeSource;

  /// Whether the battery has hit its configured reserve floor right now.
  final bool? batteryReserveReached;

  /// Whether a required-runtime target has been set at all
  /// (`requiredRuntimeHours` is not meaningful when this is false).
  final bool? requiredRuntimeConfigured;

  /// The currently configured required-runtime target (hours), live from
  /// Central.
  final double? requiredRuntimeHours;

  /// Hours of runtime firmware currently estimates remain against
  /// [requiredRuntimeHours], counting down in real time.
  final double? remainingRuntimeHours;

  /// Firmware's independent estimate of achievable runtime at the current
  /// discharge rate, regardless of the configured target.
  final double? estimatedRuntimeHours;
  final bool? runtimeEstimateValid;

  /// Whether the configured [requiredRuntimeHours] target is currently
  /// achievable given the battery's energy and discharge rate — the same
  /// ACHIEVABLE/NOT ACHIEVABLE verdict the Central console's `dashboard`
  /// command prints.
  final bool? requiredRuntimeAchievable;

  /// The homeowner-configured power budget (`P_budget`), watts.
  final double? powerBudgetWatts;

  /// The homeowner-configured power reserve (`P_reserve`), watts — held back
  /// from AUTO allocation, not a battery SoC percentage.
  final double? powerReserveWatts;

  /// `P_auto_available` — the power ceiling available for AUTO loads after
  /// budget/reserve/fixed/runtime constraints, before AUTO selection.
  final double? sustainablePowerW;

  /// Conservative total derived from relay state and configured ratings
  /// (`P_fixed + P_auto`).
  final double? estimatedTotalLoadPowerW;

  /// Alias of [sustainablePowerW] (`P_auto_available`) for call sites that
  /// think of it as "available power" rather than "sustainable power" — the
  /// same firmware number viewed from a different card.
  final double? availablePowerW;

  /// `P_fixed`.
  final double? fixedLoadPowerW;

  /// `P_auto` — power actually committed to selected AUTO loads.
  final double? autoLoadPowerW;

  /// `P_remaining` (`P_budget - P_fixed - P_auto`).
  final double? remainingPowerW;

  /// Alias of [fixedLoadPowerW] — the FIXED_ON commitment.
  final double? committedPowerW;

  /// Not currently published by firmware at the system level.
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

  /// Reserved for a future firmware field. Not currently published.
  final String? operatingEnvironment;

  /// Reserved for a future firmware field. Not currently published.
  final bool? developmentSessionActive;

  /// Reserved for a future firmware field. Not currently published at the
  /// system level (per-node fault/error counters live under `state.nodes`).
  final int? faultCount;

  /// Reserved for a future firmware summary field.
  final String? faultSummary;

  /// When this snapshot was received locally — used to decide staleness,
  /// independent of any timestamp the payload itself may carry.
  final DateTime? receivedAt;

  /// Live measured power (`battery.voltageVolts × battery.currentAmps`,
  /// published by firmware as `P_measured`) — recomputed client-side only if
  /// firmware ever omits it, so this always reflects what Central actually
  /// reported.
  double? get batteryPowerW {
    if (batteryVoltage == null || batteryCurrent == null) return null;
    return batteryVoltage! * batteryCurrent!;
  }

  static const empty = SystemStateModel();

  factory SystemStateModel.fromJson(Map<String, dynamic> json) {
    final battery = json.mapOrNull('battery') ?? const {};
    final power = json.mapOrNull('powerFlow') ?? const {};

    final lastOptimizationEpoch = json.intOrNull('lastOptimizationEpochSeconds');

    // powerFlow is only meaningful once Central has computed a power budget
    // at least once. Firmware does not publish a separate validity flag for
    // it — the budget field's own presence is the signal.
    final budget = power.doubleOrNull('P_budget');
    final powerFlowValid = budget != null;
    double? validPower(String key) => powerFlowValid ? power.doubleOrNull(key) : null;

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
      stateOfChargeValid: battery.boolOrNull('stateOfChargeValid'),
      stateOfChargeSource: battery.stringOrNull('stateOfChargeSource'),
      batteryReserveReached: battery.boolOrNull('batteryReserveReached'),
      requiredRuntimeConfigured: battery.boolOrNull('requiredRuntimeConfigured'),
      requiredRuntimeHours: battery.doubleOrNull('requiredRuntimeHours'),
      remainingRuntimeHours: battery.doubleOrNull('remainingRuntimeHours'),
      estimatedRuntimeHours: battery.doubleOrNull('estimatedRuntimeHours'),
      runtimeEstimateValid: battery.boolOrNull('runtimeEstimateValid'),
      requiredRuntimeAchievable: battery.boolOrNull('requiredRuntimeAchievable'),
      powerBudgetWatts: budget,
      powerReserveWatts: validPower('P_reserve'),
      sustainablePowerW: validPower('P_auto_available'),
      estimatedTotalLoadPowerW: powerFlowValid
          ? _sumOrNull(power.doubleOrNull('P_fixed'), power.doubleOrNull('P_auto'))
          : null,
      availablePowerW: validPower('P_auto_available'),
      fixedLoadPowerW: validPower('P_fixed'),
      autoLoadPowerW: validPower('P_auto'),
      remainingPowerW: validPower('P_remaining'),
      committedPowerW: validPower('P_fixed'),
      lastOptimizationAt: (lastOptimizationEpoch == null || lastOptimizationEpoch == 0)
          ? null
          : json.dateTimeOrNull('lastOptimizationEpochSeconds'),
      sensorInputSource: battery.stringOrNull('measurementSource'),
      receivedAt: DateTime.now(),
    );
  }
}

double? _sumOrNull(double? a, double? b) {
  if (a == null && b == null) return null;
  return (a ?? 0) + (b ?? 0);
}
