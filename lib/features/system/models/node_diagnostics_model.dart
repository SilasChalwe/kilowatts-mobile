import '../../../core/utils/json_parsing.dart';

/// Extended device diagnostics, matching `TopologyTree::appendDiagnosticsJson`
/// exactly (`lib/NodeManager/Central/TopologyTree.cpp`). Every field is
/// optional — firmware only publishes what it actually measures, and the UI
/// must show "Unavailable" rather than invent a value for anything missing
/// here.
///
/// [buildId], [siliconRevision], [cpuFrequencyMhz] and [chipTemperatureC]
/// are not currently emitted by firmware's diagnostics JSON at all (it only
/// sends firmwareVersion/chipModel/freeHeapBytes/minFreeHeapBytes/
/// flashSizeBytes/psramSizeBytes/cpuCores/resetReason) — they stay null
/// until a firmware change adds them, not because of a parsing bug.
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

  /// Device/chip die temperature — explicitly not ambient room temperature.
  final double? chipTemperatureC;
  final List<String> faults;

  factory NodeDiagnosticsModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const NodeDiagnosticsModel();
    final faults = json['faults'];
    return NodeDiagnosticsModel(
      firmwareVersion: json.stringOrNull('firmware_version'),
      buildId: json.stringOrNull('build_id'),
      chipModel: json.stringOrNull('chip_model'),
      siliconRevision: json.intOrNull('silicon_revision'),
      cpuCores: json.intOrNull('cpu_cores'),
      cpuFrequencyMhz: json.intOrNull('cpu_frequency_mhz'),
      flashSizeBytes: json.intOrNull('flash_size_bytes'),
      psramSizeBytes: json.intOrNull('psram_size_bytes'),
      freeHeapBytes: json.intOrNull('free_heap_bytes'),
      minFreeHeapBytes: json.intOrNull('min_free_heap_bytes'),
      resetReason: json.stringOrNull('reset_reason'),
      chipTemperatureC: json.doubleOrNull('chip_temperature_c'),
      faults: faults is List ? faults.whereType<String>().toList() : const [],
    );
  }
}
