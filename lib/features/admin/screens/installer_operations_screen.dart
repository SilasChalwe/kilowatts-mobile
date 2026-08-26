import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../../core/services/command_outcome.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

/// Safe non-destructive Central operations exposed by the current firmware.
/// Destructive factory-reset actions remain deliberately outside this screen.
class InstallerOperationsScreen extends StatefulWidget {
  const InstallerOperationsScreen({super.key});

  @override
  State<InstallerOperationsScreen> createState() =>
      _InstallerOperationsScreenState();
}

class _InstallerOperationsScreenState
    extends State<InstallerOperationsScreen> {
  final _interval = TextEditingController(text: '300');
  bool _optimizing = false;
  bool _savingInterval = false;
  String? _message;
  bool _messageIsError = false;

  @override
  void dispose() {
    _interval.dispose();
    super.dispose();
  }

  void _showOutcome(CommandOutcome outcome, String successText) {
    setState(() {
      _messageIsError = outcome.status == CommandStatus.failed;
      _message = _messageIsError
          ? outcome.message ?? 'Central rejected the command.'
          : successText;
    });
  }

  Future<void> _runOptimization() async {
    setState(() {
      _optimizing = true;
      _message = 'Requesting an immediate optimization cycle…';
      _messageIsError = false;
    });
    final outcome = await AppStateScope.of(context).requestOptimizationCycle();
    if (!mounted) return;
    setState(() => _optimizing = false);
    _showOutcome(outcome, 'Central accepted the optimization request.');
  }

  Future<void> _saveInterval() async {
    final seconds = int.tryParse(_interval.text.trim());
    if (seconds == null || seconds < 5 || seconds > 86400) {
      setState(() {
        _messageIsError = true;
        _message = 'Use an optimizer interval from 5 to 86,400 seconds.';
      });
      return;
    }

    setState(() {
      _savingInterval = true;
      _message = 'Sending optimizer interval to Central…';
      _messageIsError = false;
    });
    final outcome = await AppStateScope.of(
      context,
    ).setOptimizerIntervalSeconds(seconds);
    if (!mounted) return;
    setState(() => _savingInterval = false);
    _showOutcome(outcome, 'Optimizer interval confirmed at ${_friendlyInterval(seconds)}.');
  }

  String _friendlyInterval(int seconds) {
    if (seconds % 3600 == 0) return '${seconds ~/ 3600} h';
    if (seconds % 60 == 0) return '${seconds ~/ 60} min';
    return '$seconds s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('System operations')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            const Text('Central operations', style: AppTextStyles.display),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Run Best-First Search on demand or control how frequently Central automatically re-evaluates load priorities.',
              style: AppTextStyles.subtitle,
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.info.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.auto_awesome_outlined,
                          color: AppColors.info,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Best-First optimization', style: AppTextStyles.title),
                            SizedBox(height: 2),
                            Text(
                              'Uses the latest battery budget, load priorities and schedules.',
                              style: AppTextStyles.caption,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton.icon(
                    onPressed: _optimizing ? null : _runOptimization,
                    icon: _optimizing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_arrow_rounded),
                    label: Text(
                      _optimizing ? 'Waiting for Central…' : 'Run optimization now',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Automatic optimization interval', style: AppTextStyles.title),
                  const SizedBox(height: AppSpacing.xs),
                  const Text(
                    'Choose a common interval or enter a custom value. Firmware accepts 5 seconds to 24 hours.',
                    style: AppTextStyles.caption,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final preset in const [30, 60, 300, 900, 3600])
                        ChoiceChip(
                          label: Text(_friendlyInterval(preset)),
                          selected: int.tryParse(_interval.text.trim()) == preset,
                          onSelected: _savingInterval
                              ? null
                              : (_) => setState(() => _interval.text = '$preset'),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: TextField(
                      controller: _interval,
                      enabled: !_savingInterval,
                      onChanged: (_) => setState(() {}),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Custom interval (seconds)',
                        helperText: 'Default: 300 seconds (5 minutes)',
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton.icon(
                    onPressed: _savingInterval ? null : _saveInterval,
                    icon: _savingInterval
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.schedule_outlined),
                    label: Text(
                      _savingInterval ? 'Waiting for Central…' : 'Apply interval',
                    ),
                  ),
                ],
              ),
            ),
            if (_message != null) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: (_messageIsError ? AppColors.error : AppColors.success)
                      .withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      _messageIsError
                          ? Icons.error_outline_rounded
                          : Icons.check_circle_outline_rounded,
                      size: 18,
                      color: _messageIsError ? AppColors.error : AppColors.success,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        _message!,
                        style: AppTextStyles.caption.copyWith(
                          color: _messageIsError
                              ? AppColors.error
                              : AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
