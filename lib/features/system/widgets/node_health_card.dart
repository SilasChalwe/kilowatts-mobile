import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/section_card.dart';
import '../models/node_diagnostics_model.dart';

/// Every value here is optional — only what the firmware has actually
/// published is shown, everything else reads "Unavailable" rather than
/// being invented.
class NodeHealthCard extends StatelessWidget {
  const NodeHealthCard({required this.diagnostics, super.key});

  final NodeDiagnosticsModel diagnostics;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Device Health',
      child: Column(
        children: [
          SectionRow(
            label: 'Firmware Version',
            value: diagnostics.firmwareVersion,
          ),
          SectionRow(label: 'Build', value: diagnostics.buildId),
          SectionRow(label: 'Chip Model', value: diagnostics.chipModel),
          SectionRow(
            label: 'Silicon Revision',
            value: diagnostics.siliconRevision?.toString(),
          ),
          SectionRow(
            label: 'CPU Cores',
            value: diagnostics.cpuCores?.toString(),
          ),
          SectionRow(
            label: 'CPU Frequency',
            value: diagnostics.cpuFrequencyMhz == null
                ? null
                : '${diagnostics.cpuFrequencyMhz} MHz',
          ),
          SectionRow(
            label: 'Free Heap',
            value: _bytes(diagnostics.freeHeapBytes),
          ),
          SectionRow(
            label: 'Minimum Free Heap',
            value: _bytes(diagnostics.minFreeHeapBytes),
          ),
          SectionRow(label: 'Reset Reason', value: diagnostics.resetReason),
          SectionRow(
            label: 'Device Temperature',
            value: Formatters.temperatureC(diagnostics.chipTemperatureC),
          ),
          if (diagnostics.faults.isNotEmpty)
            SectionRow(label: 'Faults', value: diagnostics.faults.join(', ')),
        ],
      ),
    );
  }

  String? _bytes(int? value) {
    if (value == null) return null;
    if (value >= 1024) return '${(value / 1024).toStringAsFixed(1)} KB';
    return '$value B';
  }
}
