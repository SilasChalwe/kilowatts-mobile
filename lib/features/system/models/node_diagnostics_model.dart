import '../../../core/utils/json_parsing.dart';

/// Extended device diagnostics, matching the `diagnostics` object inside
/// each entry of `state.nodes.nodes[]` exactly (verified against a live
/// broker capture): `freeHeapBytes`, `minFreeHeapBytes`, `flashSizeBytes`,
/// `psramSizeBytes`, `siliconRevision`, `cpuCores`, `cpuFrequencyMhz`,
/// `resetReason`, `temperatureAvailable`, `temperatureCelsius` — all
/// camelCase on the wire, not snake_case. `firmwareVersion` and `chipModel`
/// are published as siblings of `diagnostics` on the node object itself, not
/// inside it, so they are passed in separately by [NodeModel.fromJson].
/// [buildId] is not published by firmware at all and stays null until a
/// firmware change adds it.
class NodeDiagnosticsModel {
  const NodeDiagnosticsModel({
    this.firmwareVersion,
    this.buildId,
    this.chipModel,
    this.siliconRevision,
    this.cpuCores,
    this.cpuFrequencyMhz,
    this.flashSizeBytes,
    this.psramSizeBytes,
    this.freeHeapBytes,
    this.minFreeHeapBytes,
    this.resetReason,
    this.temperatureAvailable,
    this.chipTemperatureC,
    this.faults = const [],
  });

  final String? firmwareVersion;
  final String? buildId;
  final String? chipModel;
  final int? siliconRevision;
  final int? cpuCores;
  final int? cpuFrequencyMhz;
  final int? flashSizeBytes;
  final int? psramSizeBytes;
  final int? freeHeapBytes;
  final int? minFreeHeapBytes;
  final String? resetReason;
  final bool? temperatureAvailable;

  /// Device/chip die temperature — explicitly not ambient room temperature.
  /// Only meaningful when [temperatureAvailable] is true.
  final double? chipTemperatureC;
  final List<String> faults;

  factory NodeDiagnosticsModel.fromJson(
    Map<String, dynamic>? json, {
    String? firmwareVersion,
    String? chipModel,
  }) {
    if (json == null) {
      return NodeDiagnosticsModel(
        firmwareVersion: firmwareVersion,
        chipModel: chipModel,
      );
    }
    final faults = json['faults'];
    return NodeDiagnosticsModel(
      firmwareVersion: firmwareVersion,
      chipModel: chipModel,
      siliconRevision: json.intOrNull('siliconRevision'),
      cpuCores: json.intOrNull('cpuCores'),
      cpuFrequencyMhz: json.intOrNull('cpuFrequencyMhz'),
      flashSizeBytes: json.intOrNull('flashSizeBytes'),
      psramSizeBytes: json.intOrNull('psramSizeBytes'),
      freeHeapBytes: json.intOrNull('freeHeapBytes'),
      minFreeHeapBytes: json.intOrNull('minFreeHeapBytes'),
      resetReason: json.stringOrNull('resetReason'),
      temperatureAvailable: json.boolOrNull('temperatureAvailable'),
      chipTemperatureC: json.doubleOrNull('temperatureCelsius'),
      faults: faults is List ? faults.whereType<String>().toList() : const [],
    );
  }
}
