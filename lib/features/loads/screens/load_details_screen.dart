import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../../core/services/command_outcome.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/responsive_content.dart';
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
    final draft = await showDialog<_LoadConfigurationDraft>(
      context: context,
      builder: (_) => _LoadConfigurationDialog(load: load),
    );
    if (draft == null || !mounted) return;

    setState(() {
      _isSaving = true;
      _saveFailed = false;
      _saveMessage = 'Sending configuration to Central…';
    });

    final outcome = await AppStateScope.of(context).updateLoadConfiguration(
      nodeMac: load.owningNodeMac,
      relayPin: load.relayPin,
      mode: draft.mode,
      currentRequestedState: load.requestedState ?? load.confirmedState ?? false,
      priority: draft.priority,
      schedule: draft.mode == LoadMode.fixed
          ? LoadSchedule.disabled
          : draft.schedule,
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

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);

    return ValueListenableBuilder<List<LoadModel>>(
      valueListenable: appState.loads,
      builder: (context, loads, _) {
        final matches = loads.where((candidate) => candidate.id == widget.load.id);
        final load = matches.isEmpty ? widget.load : matches.first;
        final priorityLevel = LoadPriorityLevel.bucketFor(load.priority);

        return Scaffold(
          appBar: AppBar(title: const Text('Load details')),
          body: SafeArea(
            child: ListView(
              children: [
                ResponsiveContent(
                  maxWidth: 1120,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PageHeader(
                        eyebrow: load.owningNodeName ?? 'Connected load',
                        title: load.name,
                        subtitle: load.owningNodeName == null
                            ? load.owningNodeMac
                            : 'Relay GPIO ${load.relayPin} · ${load.owningNodeMac}',
                        actions: [
                          StatusBadge(
                            label: !load.available
                                ? 'Unavailable'
                                : load.displayState == true
                                    ? 'On'
                                    : 'Off',
                            tone: !load.available
                                ? StatusTone.negative
                                : load.displayState == true
                                    ? StatusTone.positive
                                    : StatusTone.neutral,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      ResponsiveCardGrid(
                        minCardWidth: 360,
                        maxColumns: 2,
                        children: [
                          SectionCard(
                            title: 'Control',
                            subtitle: load.mode == LoadMode.fixed
                                ? 'Manual state for this fixed load.'
                                : 'Automatic loads are controlled by the optimizer.',
                            child: LoadStateControl(load: load),
                          ),
                          SectionCard(
                            title: 'Configuration',
                            subtitle: 'Current load planning settings.',
                            child: Column(
                              children: [
                                SectionRow(
                                  label: 'Mode',
                                  value: load.mode == LoadMode.auto
                                      ? 'Automatic'
                                      : 'Fixed',
                                ),
                                SectionRow(
                                  label: 'Priority',
                                  value:
                                      '${priorityLevel.label} · ${load.priority}/10',
                                ),
                                SectionRow(
                                  label: 'Preferred schedule',
                                  value: load.schedule.enabled
                                      ? _scheduleLabel(load.schedule)
                                      : 'Not scheduled',
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: OutlinedButton.icon(
                                    onPressed: _isSaving
                                        ? null
                                        : () => _editConfiguration(load),
                                    icon: const Icon(Icons.edit_outlined, size: 18),
                                    label: Text(
                                      _isSaving
                                          ? 'Applying…'
                                          : 'Edit configuration',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      SectionCard(
                        title: 'Planning data',
                        subtitle:
                            'Values used by Central when evaluating this load.',
                        child: Column(
                          children: [
                            SectionRow(
                              label: 'Planned running power',
                              value: Formatters.power(load.plannedPowerW),
                            ),
                            SectionRow(
                              label: 'Power source',
                              value: 'Installer rating',
                            ),
                            SectionRow(
                              label: 'Relay channel',
                              value: 'GPIO ${load.relayPin}',
                            ),
                            SectionRow(
                              label: 'Last telemetry update',
                              value: Formatters.relativeTime(load.lastUpdated),
                            ),
                            if (load.rejectionReason != null)
                              SectionRow(
                                label: 'Optimizer decision',
                                value: load.rejectionReason!.friendlyText,
                              ),
                          ],
                        ),
                      ),
                      if (_saveMessage != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        _SaveFeedback(
                          message: _saveMessage!,
                          failed: _saveFailed,
                          pending: _isSaving,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _scheduleLabel(LoadSchedule schedule) {
    final startHour = schedule.startHour ?? 0;
    final startMinute = schedule.startMinute ?? 0;
    final endHour = schedule.endHour ?? ((startHour + 1) % 24);
    final endMinute = schedule.endMinute ?? startMinute;
    return '${Formatters.timeOfDay(startHour, startMinute)} – ${Formatters.timeOfDay(endHour, endMinute)}';
  }
}

class _LoadConfigurationDraft {
  const _LoadConfigurationDraft({
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
  late LoadMode _mode;
  late int _priority;
  late LoadSchedule _schedule;

  @override
  void initState() {
    super.initState();
    _mode = widget.load.mode;
    _priority = widget.load.priority;
    _schedule = widget.load.schedule;
  }

  void _apply() {
    Navigator.of(context).pop(
      _LoadConfigurationDraft(
        mode: _mode,
        priority: _priority,
        schedule: _mode == LoadMode.fixed ? LoadSchedule.disabled : _schedule,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit ${widget.load.name}'),
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
              const SizedBox(height: AppSpacing.lg),
              const Text('Priority', style: AppTextStyles.label),
              const SizedBox(height: 2),
              const Text(
                'Higher values are preferred when available power cannot serve every automatic load.',
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: AppSpacing.xs),
              PrioritySelector(
                value: _priority,
                onChanged: (value) => setState(() => _priority = value),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_mode == LoadMode.auto) ...[
                const Text('Preferred schedule', style: AppTextStyles.label),
                const SizedBox(height: AppSpacing.xs),
                ScheduleEditor(
                  schedule: _schedule,
                  onChanged: (schedule) => setState(() => _schedule = schedule),
                ),
              ] else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: const Text(
                    'Fixed loads use manual ON/OFF control, so no automatic schedule is applied.',
                    style: AppTextStyles.caption,
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _apply,
          icon: const Icon(Icons.check_rounded, size: 18),
          label: const Text('Apply changes'),
        ),
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
    final background = failed
        ? AppColors.errorSoft
        : pending
            ? AppColors.infoSoft
            : AppColors.successSoft;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Icon(
            failed
                ? Icons.error_outline_rounded
                : pending
                    ? Icons.sync_rounded
                    : Icons.check_circle_outline_rounded,
            size: 18,
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
