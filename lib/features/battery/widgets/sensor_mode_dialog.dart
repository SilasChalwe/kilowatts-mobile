import 'package:flutter/material.dart';

import '../../../core/services/command_outcome.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// Modal for switching measurement source. Picking "Real sensor" applies
/// immediately with nothing else to enter. Picking "Simulation" reveals the
/// voltage/current/SoC fields in the same dialog — there is no separate
/// screen for it, so a homeowner never sees the simulation inputs unless
/// they've deliberately chosen simulation mode.
Future<void> showSensorModeDialog(
  BuildContext context, {
  required bool? currentlySimulated,
  required Future<CommandOutcome> Function({required bool useHardwareSensor})
  onSetMode,
  required Future<CommandOutcome> Function({double? voltage, double? current, double? soc})
  onSetSimulatedValues,
}) => showDialog<void>(
  context: context,
  builder: (_) => _SensorModeDialog(
    currentlySimulated: currentlySimulated,
    onSetMode: onSetMode,
    onSetSimulatedValues: onSetSimulatedValues,
  ),
);

class _SensorModeDialog extends StatefulWidget {
  const _SensorModeDialog({
    required this.currentlySimulated,
    required this.onSetMode,
    required this.onSetSimulatedValues,
  });

  final bool? currentlySimulated;
  final Future<CommandOutcome> Function({required bool useHardwareSensor}) onSetMode;
  final Future<CommandOutcome> Function({double? voltage, double? current, double? soc})
  onSetSimulatedValues;

  @override
  State<_SensorModeDialog> createState() => _SensorModeDialogState();
}

class _SensorModeDialogState extends State<_SensorModeDialog> {
  late bool _useHardwareSensor;
  late final TextEditingController _voltage;
  late final TextEditingController _current;
  late final TextEditingController _soc;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _useHardwareSensor = widget.currentlySimulated == false;
    _voltage = TextEditingController();
    _current = TextEditingController();
    _soc = TextEditingController();
  }

  @override
  void dispose() {
    _voltage.dispose();
    _current.dispose();
    _soc.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    setState(() {
      _sending = true;
      _error = null;
    });

    final modeOutcome = await widget.onSetMode(useHardwareSensor: _useHardwareSensor);
    if (!mounted) return;
    if (!modeOutcome.isConfirmed) {
      setState(() {
        _sending = false;
        _error = modeOutcome.message ?? 'Central rejected this command.';
      });
      return;
    }

    if (!_useHardwareSensor) {
      final hasVoltage = _voltage.text.trim().isNotEmpty;
      final hasCurrent = _current.text.trim().isNotEmpty;
      final hasSoc = _soc.text.trim().isNotEmpty;
      if (hasVoltage != hasCurrent) {
        setState(() {
          _sending = false;
          _error = 'Provide voltage and current together.';
        });
        return;
      }
      if (hasVoltage || hasSoc) {
        final valuesOutcome = await widget.onSetSimulatedValues(
          voltage: hasVoltage ? double.tryParse(_voltage.text) : null,
          current: hasCurrent ? double.tryParse(_current.text) : null,
          soc: hasSoc ? double.tryParse(_soc.text) : null,
        );
        if (!mounted) return;
        if (!valuesOutcome.isConfirmed) {
          setState(() {
            _sending = false;
            _error = valuesOutcome.message ?? 'Central rejected the simulated values.';
          });
          return;
        }
      }
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select sensor'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: _ModeChoice(
                    label: 'Real sensor (INA219)',
                    selected: _useHardwareSensor,
                    enabled: !_sending,
                    onTap: () => setState(() => _useHardwareSensor = true),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _ModeChoice(
                    label: 'Simulation',
                    selected: !_useHardwareSensor,
                    enabled: !_sending,
                    onTap: () => setState(() => _useHardwareSensor = false),
                  ),
                ),
              ],
            ),
            if (!_useHardwareSensor) ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _voltage,
                      enabled: !_sending,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Voltage (V)'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: TextField(
                      controller: _current,
                      enabled: !_sending,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Current (A)'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: TextField(
                      controller: _soc,
                      enabled: !_sending,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'SoC (%)'),
                    ),
                  ),
                ],
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(_error!, style: const TextStyle(color: AppColors.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _sending ? null : _apply,
          child: Text(_sending ? 'Sending…' : 'Apply'),
        ),
      ],
    );
  }
}

class _ModeChoice extends StatelessWidget {
  const _ModeChoice({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return selected
        ? FilledButton(onPressed: enabled ? onTap : null, child: Text(label))
        : OutlinedButton(onPressed: enabled ? onTap : null, child: Text(label));
  }
}
