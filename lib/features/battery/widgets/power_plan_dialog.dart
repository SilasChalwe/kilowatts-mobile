import 'package:flutter/material.dart';

import '../../../core/services/command_outcome.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// Shows the power-plan editor as a modal instead of inline fields on the
/// card. `onApply` mirrors `AppState.setBatteryPlan` exactly — every field
/// is pre-filled with the current live value, so changing only the runtime
/// (a case the frontend explicitly supports independent of budget/reserve)
/// doesn't require re-entering anything else.
Future<void> showPowerPlanDialog(
  BuildContext context, {
  required double? initialBudget,
  required double? initialReserve,
  required double? initialMinSoc,
  required double? initialRuntime,
  required Future<CommandOutcome> Function({
    required double budget,
    required double reserve,
    required double minSoc,
    double? runtime,
  })
  onApply,
}) => showDialog<void>(
  context: context,
  builder: (_) => _PowerPlanDialog(
    initialBudget: initialBudget,
    initialReserve: initialReserve,
    initialMinSoc: initialMinSoc,
    initialRuntime: initialRuntime,
    onApply: onApply,
  ),
);

class _PowerPlanDialog extends StatefulWidget {
  const _PowerPlanDialog({
    required this.initialBudget,
    required this.initialReserve,
    required this.initialMinSoc,
    required this.initialRuntime,
    required this.onApply,
  });

  final double? initialBudget;
  final double? initialReserve;
  final double? initialMinSoc;
  final double? initialRuntime;
  final Future<CommandOutcome> Function({
    required double budget,
    required double reserve,
    required double minSoc,
    double? runtime,
  })
  onApply;

  @override
  State<_PowerPlanDialog> createState() => _PowerPlanDialogState();
}

class _PowerPlanDialogState extends State<_PowerPlanDialog> {
  late final TextEditingController _budget;
  late final TextEditingController _reserve;
  late final TextEditingController _minSoc;
  late final TextEditingController _runtime;
  bool _sending = false;
  String? _error;

  static String _formatOrEmpty(double? value) =>
      value == null ? '' : value.toStringAsFixed(value % 1 == 0 ? 0 : 1);

  @override
  void initState() {
    super.initState();
    _budget = TextEditingController(text: _formatOrEmpty(widget.initialBudget));
    _reserve = TextEditingController(text: _formatOrEmpty(widget.initialReserve));
    _minSoc = TextEditingController(text: _formatOrEmpty(widget.initialMinSoc));
    _runtime = TextEditingController(text: _formatOrEmpty(widget.initialRuntime));
  }

  @override
  void dispose() {
    _budget.dispose();
    _reserve.dispose();
    _minSoc.dispose();
    _runtime.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    final budget = double.tryParse(_budget.text);
    final reserve = double.tryParse(_reserve.text);
    final minSoc = double.tryParse(_minSoc.text);
    final runtimeText = _runtime.text.trim();
    final runtime = runtimeText.isEmpty ? null : double.tryParse(runtimeText);

    if (budget == null || reserve == null || minSoc == null) {
      setState(() => _error = 'Budget, reserve and minimum SoC are all required.');
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });
    final outcome = await widget.onApply(
      budget: budget,
      reserve: reserve,
      minSoc: minSoc,
      runtime: runtime,
    );
    if (!mounted) return;
    if (outcome.isConfirmed) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _sending = false;
      _error = outcome.message ?? 'Central rejected this command.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Power plan'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _budget,
                    enabled: !_sending,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Budget (W)'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: TextField(
                    controller: _reserve,
                    enabled: !_sending,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Reserve (W)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minSoc,
                    enabled: !_sending,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Minimum SoC (%)'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: TextField(
                    controller: _runtime,
                    enabled: !_sending,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Runtime (h, optional)'),
                  ),
                ),
              ],
            ),
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
