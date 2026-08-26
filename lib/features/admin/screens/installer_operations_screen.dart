import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../../core/services/command_outcome.dart';
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
      _message = null;
    });
    final outcome = await AppStateScope.of(context).requestOptimizationCycle();
    if (!mounted) return;
    setState(() => _optimizing = false);
    _showOutcome(outcome, 'Optimization cycle requested successfully.');
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
      _message = null;
    });
    final outcome = await AppStateScope.of(
      context,
    ).setOptimizerIntervalSeconds(seconds);
    if (!mounted) return;
    setState(() => _savingInterval = false);
    _showOutcome(outcome, 'Optimizer interval updated to $seconds seconds.');
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const Text('System operations', style: AppTextStyles.display),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Run the Best-First planner on demand or change how often Central optimizes loads automatically.',
            style: AppTextStyles.subtitle,
          ),
          const SizedBox(height: AppSpacing.lg),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Best-First optimization',
                    style: AppTextStyles.title,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  const Text(
                    'Requests an immediate planning cycle using the current battery budget, load priorities and schedules.',
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
                        : const Icon(Icons.play_arrow_outlined),
                    label: Text(
                      _optimizing ? 'Requesting…' : 'Run optimization now',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Automatic interval', style: AppTextStyles.title),
                  const SizedBox(height: AppSpacing.xs),
                  const Text(
                    'Firmware accepts 5 seconds to 24 hours. The default is 300 seconds (5 minutes).',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: TextField(
                      controller: _interval,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Interval (seconds)',
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
                      _savingInterval ? 'Saving…' : 'Save optimizer interval',
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_message != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              _message!,
              style: TextStyle(
                color: _messageIsError
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
