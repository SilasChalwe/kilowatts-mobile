import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../../core/services/command_outcome.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/section_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../models/load_model.dart';
import '../widgets/load_mode_selector.dart';
import '../widgets/load_state_control.dart';
import '../widgets/priority_selector.dart';
import '../widgets/schedule_editor.dart';

class LoadDetailsScreen extends StatefulWidget {
  const LoadDetailsScreen({required this.load, super.key});

  final LoadModel load;

  @override
  State<LoadDetailsScreen> createState() => _LoadDetailsScreenState();
}

class _LoadDetailsScreenState extends State<LoadDetailsScreen> {
  late LoadMode _mode = widget.load.mode;
  late int _priority = widget.load.priority;
  late LoadSchedule _schedule = widget.load.schedule;
  bool _isSaving = false;
  String? _saveMessage;
  bool _saveFailed = false;

  Future<void> _saveConfiguration() async {
    setState(() {
      _isSaving = true;
      _saveMessage = 'Sending configuration to Central…';
      _saveFailed = false;
    });

    final effectiveSchedule = _mode == LoadMode.fixed
        ? LoadSchedule.disabled
        : _schedule;

    final outcome = await AppStateScope.of(context).updateLoadConfiguration(
      nodeMac: widget.load.owningNodeMac,
      relayPin: widget.load.relayPin,
      mode: _mode,
      currentRequestedState:
          widget.load.requestedState ?? widget.load.confirmedState ?? false,
      priority: _priority,
      schedule: effectiveSchedule,
    );

    if (!mounted) return;
    setState(() {
      _isSaving = false;
      _saveFailed = outcome.status == CommandStatus.failed;
      _saveMessage = outcome.status == CommandStatus.confirmed
          ? 'Configuration confirmed by Central.'
          : outcome.message ?? 'Central rejected this configuration.';
      if (!_saveFailed && _mode == LoadMode.fixed) {
        _schedule = LoadSchedule.disabled;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);

    return ValueListenableBuilder<List<LoadModel>>(
      valueListenable: appState.loads,
      builder: (context, loads, _) {
        final matches = loads.where((l) => l.id == widget.load.id);
        final load = matches.isEmpty ? widget.load : matches.first;
        final priorityLevel = LoadPriorityLevel.bucketFor(load.priority);

        return Scaffold(
          appBar: AppBar(title: Text(load.name)),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: load.displayState == true
                              ? AppColors.success.withValues(alpha: 0.10)
                              : AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          load.displayState == true
                              ? Icons.flash_on_rounded
                              : Icons.power_settings_new_rounded,
                          color: load.displayState == true
                              ? AppColors.success
                              : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(load.name, style: AppTextStyles.title),
                            const SizedBox(height: 3),
                            Text(
                              load.owningNodeName ?? load.owningNodeMac,
                              style: AppTextStyles.caption,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Wrap(
                              spacing: AppSpacing.xs,
                              runSpacing: AppSpacing.xs,
                              children: [
                                StatusBadge(
                                  label: load.mode == LoadMode.auto
                                      ? 'Automatic'
                                      : 'Fixed',
                                  tone: StatusTone.neutral,
                                  showDot: false,
                                ),
                                StatusBadge(
                                  label: '${priorityLevel.label} priority',
                                  tone: StatusTone.info,
                                  showDot: false,
                                ),
                                StatusBadge(
                                  label: load.available
                                      ? (load.displayState == true ? 'On' : 'Off')
                                      : 'Unavailable',
                                  tone: !load.available
                                      ? StatusTone.negative
                                      : load.displayState == true
                                          ? StatusTone.positive
                                          : StatusTone.neutral,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                SectionCard(
                  title: 'Control',
                  child: LoadStateControl(load: load),
                ),
                const SizedBox(height: AppSpacing.md),
                SectionCard(
                  title: 'Planning configuration',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Mode', style: AppTextStyles.label),
                      const SizedBox(height: AppSpacing.xs),
                      LoadModeSelector(
                        value: _mode,
                        onChanged: (value) {
                          setState(() {
                            _mode = value;
                            _saveMessage = null;
                          });
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const Text('Priority', style: AppTextStyles.label),
                      const SizedBox(height: 2),
                      Text(
                        'Higher priority loads are preferred by Best-First Search when power is limited.',
                        style: AppTextStyles.caption,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      PrioritySelector(
                        value: _priority,
                        onChanged: (value) {
                          setState(() {
                            _priority = value;
                            _saveMessage = null;
                          });
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (_mode == LoadMode.auto) ...[
                        const Text('Preferred schedule', style: AppTextStyles.label),
                        const SizedBox(height: 2),
                        const Text(
                          'The load remains automatic; this window only changes when it is eligible to be selected.',
                          style: AppTextStyles.caption,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        ScheduleEditor(
                          schedule: _schedule,
                          onChanged: (schedule) {
                            setState(() {
                              _schedule = schedule;
                              _saveMessage = null;
                            });
                          },
                        ),
                      ] else
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'Schedules apply only in Automatic mode. Fixed mode follows the manual ON/OFF request.',
                            style: AppTextStyles.caption,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                SectionCard(
                  title: 'Planning data',
                  child: Column(
                    children: [
                      SectionRow(
                        label: 'Planned running power',
                        value: Formatters.power(load.plannedPowerW),
                      ),
                      SectionRow(
                        label: 'Relay channel',
                        value: '${load.relayPin}',
                      ),
                      SectionRow(
                        label: 'Last update',
                        value: Formatters.relativeTime(load.lastUpdated),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Power is the installer-entered planning rating, not live per-load metering.',
                          style: AppTextStyles.caption,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                PrimaryButton(
                  label: _isSaving ? 'Waiting for Central…' : 'Apply configuration',
                  isLoading: _isSaving,
                  onPressed: _isSaving ? null : _saveConfiguration,
                ),
                if (_saveMessage != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  _SaveFeedback(
                    message: _saveMessage!,
                    failed: _saveFailed,
                    pending: _isSaving,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SaveFeedback extends StatelessWidget {
  const _SaveFeedback({
    required this.message,
    required this.failed,
    required this.pending,
  });

  final String message;
  final bool failed;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final color = failed
        ? AppColors.error
        : pending
            ? AppColors.info
            : AppColors.success;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            failed
                ? Icons.error_outline_rounded
                : pending
                    ? Icons.sync_rounded
                    : Icons.check_circle_outline_rounded,
            size: 17,
            color: color,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.caption.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
