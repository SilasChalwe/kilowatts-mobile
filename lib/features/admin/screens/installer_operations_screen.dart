import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../../core/services/command_outcome.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/section_card.dart';

class InstallerOperationsScreen extends StatefulWidget {
  const InstallerOperationsScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<InstallerOperationsScreen> createState() =>
      _InstallerOperationsScreenState();
}

class _InstallerOperationsScreenState extends State<InstallerOperationsScreen> {
  bool _optimizing = false;
  bool _savingInterval = false;
  bool _loadedInterval = false;
  String? _message;
  bool _messageIsError = false;
  int? _lastAppliedInterval;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadedInterval) return;
    _loadedInterval = true;
    _loadLastInterval();
  }

  Future<void> _loadLastInterval() async {
    final value = await AppStateScope.of(
      context,
    ).readLastInstallerOptimizerIntervalSeconds();
    if (!mounted) return;
    setState(() => _lastAppliedInterval = value);
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
    _showOutcome(outcome, 'Optimization request confirmed by Central.');
  }

  Future<void> _changeInterval() async {
    final seconds = await showDialog<int>(
      context: context,
      builder: (_) => _IntervalDialog(initial: _lastAppliedInterval),
    );
    if (seconds == null || !mounted) return;

    setState(() {
      _savingInterval = true;
      _message = null;
    });
    final appState = AppStateScope.of(context);
    final outcome = await appState.setOptimizerIntervalSeconds(seconds);
    if (!mounted) return;

    if (outcome.isConfirmed) {
      await appState.cacheLastInstallerOptimizerIntervalSeconds(seconds);
      if (!mounted) return;
    }

    setState(() {
      _savingInterval = false;
      if (outcome.isConfirmed) _lastAppliedInterval = seconds;
    });
    _showOutcome(
      outcome,
      'Optimization interval confirmed at ${_friendlyInterval(seconds)}.',
    );
  }

  static String _friendlyInterval(int seconds) {
    if (seconds % 3600 == 0) return '${seconds ~/ 3600} h';
    if (seconds % 60 == 0) return '${seconds ~/ 60} min';
    return '$seconds s';
  }

  Widget _content(BuildContext context, {required bool showPageHeader}) {
    final appState = AppStateScope.of(context);
    return ValueListenableBuilder(
      valueListenable: appState.systemState,
      builder: (context, state, _) {
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            if (showPageHeader) ...[
              const PageHeader(
                title: 'System operations',
                subtitle: 'Run optimization and control its automatic cadence.',
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            LayoutBuilder(
              builder: (context, constraints) {
                final twoColumns = constraints.maxWidth >= 760;
                final gap = AppSpacing.md;
                final width = twoColumns
                    ? (constraints.maxWidth - gap) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    SizedBox(
                      width: width,
                      child: SectionCard(
                        title: 'Best-First optimization',
                        child: Column(
                          children: [
                            SectionRow(
                              label: 'Last optimization',
                              value: Formatters.relativeTime(
                                state?.lastOptimizationAt,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Align(
                              alignment: Alignment.centerRight,
                              child: FilledButton.icon(
                                onPressed: _optimizing ? null : _runOptimization,
                                icon: _optimizing
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.play_arrow_rounded),
                                label: Text(
                                  _optimizing ? 'Requesting…' : 'Run now',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: SectionCard(
                        title: 'Automatic optimization',
                        child: Column(
                          children: [
                            SectionRow(
                              label: 'Interval',
                              value: _lastAppliedInterval == null
                                  ? 'Not published by Central'
                                  : '${_friendlyInterval(_lastAppliedInterval!)} · last applied here',
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Align(
                              alignment: Alignment.centerRight,
                              child: OutlinedButton.icon(
                                onPressed:
                                    _savingInterval ? null : _changeInterval,
                                icon: const Icon(Icons.edit_outlined),
                                label: Text(
                                  _savingInterval
                                      ? 'Applying…'
                                      : 'Change interval',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
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
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return Material(
        color: Colors.transparent,
        child: SafeArea(child: _content(context, showPageHeader: true)),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('System operations')),
      body: SafeArea(child: _content(context, showPageHeader: false)),
    );
  }
}

class _IntervalDialog extends StatefulWidget {
  const _IntervalDialog({this.initial});

  final int? initial;

  @override
  State<_IntervalDialog> createState() => _IntervalDialogState();
}

class _IntervalDialogState extends State<_IntervalDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initial == null ? '' : '${widget.initial}',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _select(int seconds) {
    setState(() => _controller.text = '$seconds');
  }

  void _save() {
    final seconds = int.tryParse(_controller.text.trim());
    if (seconds == null || seconds < 5 || seconds > 86400) return;
    Navigator.of(context).pop(seconds);
  }

  @override
  Widget build(BuildContext context) {
    final selected = int.tryParse(_controller.text.trim());
    return AlertDialog(
      title: const Text('Change optimization interval'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final preset in const [30, 60, 300, 900, 3600])
                  ChoiceChip(
                    label: Text(
                      _InstallerOperationsScreenState._friendlyInterval(preset),
                    ),
                    selected: selected == preset,
                    onSelected: (_) => _select(preset),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _controller,
              onChanged: (_) => setState(() {}),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Custom interval (seconds)',
                helperText: '5 to 86,400 seconds',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Apply')),
      ],
    );
  }
}
