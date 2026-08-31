import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/section_card.dart';
import '../../system/models/system_state_model.dart';
import 'sensor_mode_dialog.dart';

/// Homeowner-facing control for the same measurement-source and simulation
/// commands previously only reachable from Central's serial console
/// (`sensor sim` / `sensor ina219` / `sensor values`). Switching source (and,
/// when simulating, supplying values) happens in a modal
/// (`showSensorModeDialog`) reached via "Select sensor" — the simulation
/// input fields only ever appear once simulation is deliberately chosen, not
/// on this card by default. "Optimize now" stays a direct, one-tap action on
/// the card itself (the same on-demand trigger as the console's `optimize`
/// command) since forcing a planning cycle is something a homeowner reaches
/// for often, unlike switching measurement source.
class SensorDiagnosticsCard extends StatefulWidget {
  const SensorDiagnosticsCard({required this.state, this.isLive = true, super.key});

  final SystemStateModel state;

  /// Whether [state] is a live broadcast from a currently-connected Central
  /// node, as opposed to a value cached locally from a previous session. See
  /// `BatteryReserveCard.isLive` for why this matters — sending a command to
  /// a node already known to be offline is misleading, not just pointless.
  final bool isLive;

  @override
  State<SensorDiagnosticsCard> createState() => _SensorDiagnosticsCardState();
}

class _SensorDiagnosticsCardState extends State<SensorDiagnosticsCard> {
  bool _isOptimizing = false;

  Future<void> _openSensorDialog() async {
    final appState = AppStateScope.of(context);
    final currentlySimulated = widget.state.sensorInputSource == 'SIMULATED'
        ? true
        : widget.state.sensorInputSource == 'HARDWARE'
        ? false
        : null;
    await showSensorModeDialog(
      context,
      currentlySimulated: currentlySimulated,
      onSetMode: ({required useHardwareSensor}) =>
          appState.setSensorMode(useHardwareSensor: useHardwareSensor),
      onSetSimulatedValues: ({voltage, current, soc}) =>
          appState.setSimulatedValues(voltage: voltage, current: current, soc: soc),
    );
  }

  Future<void> _optimizeNow() async {
    setState(() => _isOptimizing = true);
    final outcome = await AppStateScope.of(context).triggerOptimizeNow();
    if (!mounted) return;
    setState(() => _isOptimizing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          outcome.isConfirmed
              ? 'Central ran an optimization cycle now.'
              : outcome.message ?? 'Central rejected this command.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLive = widget.isLive;
    final source = isLive ? widget.state.sensorInputSource : null;
    final canAct = isLive && !_isOptimizing;

    return SectionCard(
      title: 'Measurement & diagnostics',
      trailing: IconButton(
        icon: const Icon(Icons.more_vert),
        tooltip: 'Select sensor',
        onPressed: canAct ? _openSensorDialog : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isLive)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.errorSoft,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                'Not connected to Central — controls below are disabled.',
                style: AppTextStyles.caption.copyWith(color: AppColors.error),
              ),
            ),
          SectionRow(label: 'Current source', value: source ?? 'Unavailable'),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: canAct ? _optimizeNow : null,
              child: Text(_isOptimizing ? 'Optimizing…' : 'Optimize now'),
            ),
          ),
        ],
      ),
    );
  }
}
