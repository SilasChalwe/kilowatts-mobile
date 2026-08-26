import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../../core/services/command_outcome.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
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
  bool _isSaving = false;
  String? _saveMessage;
  bool _saveFailed = false;

  Future<void> _editConfiguration(LoadModel load) async {
    final draft = await showDialog<_LoadConfigDraft>(
      context: context,
      builder: (_) => _LoadConfigurationDialog(load: load),
    );
    if (draft == null || !mounted) return;

    setState(() {
      _isSaving = true;
      _saveMessage = 'Sending configuration to Central…';
      _saveFailed = false;
    });

    final effectiveSchedule = draft.mode == LoadMode.fixed
        ? LoadSchedule.disabled
        : draft.schedule;

    final outcome = await AppStateScope.of(context).updateLoadConfiguration(
      nodeMac: load.owningNodeMac,
      relayPin: load.relayPin,
      mode: draft.mode,
      currentRequestedState:
          load.requestedState ?? load.confirmedState ?? false,
      priority: draft.priority,
      schedule: effectiveSchedule,
    );

    if (!mounted) return;
    setState(() {
      _isSaving = false;
      _saveFailed = outcome.status == CommandStatus.failed;
      _saveMessage = outcome.status == CommandStatus.confirmed
          ? 'Configuration confirmed by Central.'
          : outcome.message ?? 'Central rejected this configuration.';
    });
  }

  Widget _hero(LoadModel load) {
    final priorityLevel = LoadPriorityLevel.bucketFor(load.priority);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
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
                      label: load.mode == LoadMode.auto ? 'Automatic' : 'Fixed',
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
    );
  }

  Widget _controlCard(LoadModel load) {
    return SectionCard(
      title: 'Current control',
      child: LoadStateControl(load: load),
    );
  }

  String _scheduleText(LoadSchedule schedule) {
    if (!schedule.enabled) return 'Not scheduled';
    return '${Formatters.timeOfDay(schedule.startHour ?? 0, schedule.startMinute ?? 0)} – ${Formatters.timeOfDay(schedule.endHour ?? 0, schedule.endMinute ?? 0)}';
  }

  Widget _planningCard(LoadModel load) {
    return SectionCard(
      title: 'Planning configuration',
      child: Column(
        children: [
          SectionRow(
            label: 'Mode',
            value: load.mode == LoadMode.auto ? 'Automatic' : 'Fixed',
          ),
          SectionRow(label: 'Priority', value: '${load.priority}/10'),
          SectionRow(label: 'Schedule', value: _scheduleText(load.schedule)),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: _isSaving ? null : () => _editConfiguration(load),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: Text(_isSaving ? 'Applying…' : 'Edit configuration'),
            ),
          ),
          if (_saveMessage != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _SaveFeedback(
              message: _saveMessage!,
              failed: _saveFailed,
              pending: _isSaving,
            ),
          ],
        ],
      ),
    );
  }

  Widget _planningData(LoadModel load) {
    return SectionCard(
      title: 'Planning data',
      child: Column(
        children: [
          SectionRow(
            label: 'Running power',
            value: Formatters.power(load.plannedPowerW),
          ),
          SectionRow(label: 'Relay channel', value: 'GPIO ${load.relayPin}'),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);

    return ValueListenableBuilder<List<LoadModel>>(
      valueListenable: appState.loads,
      builder: (context, loads, _) {
        final matches = loads.where((l) => l.id == widget.load.id);
        final load = matches.isEmpty ? widget.load : matches.first;

        return Scaffold(
          appBar: AppBar(title: const Text('Load details')),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                _hero(load),
                const SizedBox(height: AppSpacing.md),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final twoColumns = constraints.maxWidth >= 900;
                    final gap = AppSpacing.md;
                    final width = twoColumns
                        ? (constraints.maxWidth - gap) / 2
                        : constraints.maxWidth;
                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      crossAxisAlignment: WrapCrossAlignment.start,
                      children: [
                        SizedBox(
                          width: width,
                          child: Column(
                            children: [
                              _controlCard(load),
                              const SizedBox(height: AppSpacing.md),
                              _planningData(load),
                            ],
                          ),
                        ),
                        SizedBox(width: width, child: _planningCard(load)),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LoadConfigDraft {
  const _LoadConfigDraft({
    required this.mode,
    required this.priority,
    required this.schedule,
  });

  final LoadMode mode;
  final int priority;
  final LoadSchedule schedule;
}

class _LoadConfigurationDialog extends StatefulWidget {
  const _LoadConfigurationDialog({required this.load});

  final LoadModel load;

  @override
  State<_LoadConfigurationDialog> createState() =>
      _LoadConfigurationDialogState();
}

class _LoadConfigurationDialogState extends State<_LoadConfigurationDialog> {
  late LoadMode _mode = widget.load.mode;
  late int _priority = widget.load.priority;
  late LoadSchedule _schedule = widget.load.schedule;

  void _save() {
    Navigator.of(context).pop(
      _LoadConfigDraft(
        mode: _mode,
        priority: _priority,
        schedule: _mode == LoadMode.fixed ? LoadSchedule.disabled : _schedule,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit planning configuration'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Mode', style: AppTextStyles.label),
              const SizedBox(height: AppSpacing.xs),
              LoadModeSelector(
                value: _mode,
                onChanged: (value) => setState(() => _mode = value),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  const Expanded(
                    child: Text('Priority', style: AppTextStyles.label),
                  ),
                  Text('$_priority/10', style: AppTextStyles.caption),
                ],
              ),
              const SizedBox(height: 2),
              const Text(
                'Higher priority loads are preferred when available power is limited.',
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: AppSpacing.xs),
              PrioritySelector(
                value: _priority,
                onChanged: (value) => setState(() => _priority = value),
              ),
              if (_mode == LoadMode.auto) ...[
                const SizedBox(height: AppSpacing.md),
                const Text('Preferred schedule', style: AppTextStyles.label),
                const SizedBox(height: AppSpacing.xs),
                ScheduleEditor(
                  schedule: _schedule,
                  onChanged: (schedule) => setState(() => _schedule = schedule),
                ),
              ] else ...[
                const SizedBox(height: AppSpacing.md),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Fixed mode follows the manual ON/OFF request. Scheduling is available in Automatic mode.',
                    style: AppTextStyles.caption,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save changes')),
      ],
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
