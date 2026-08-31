import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../../core/services/command_outcome.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/responsive_content.dart';
import '../../../core/widgets/section_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../models/load_model.dart';
import '../widgets/load_configuration_dialog.dart';
import '../widgets/load_state_control.dart';

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
  Future<void> _removeLoad(LoadModel load) async {
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Remove ${load.name}?',
      message:
          'This unregisters the load from ${load.owningNodeName ?? load.owningNodeMac}.',
      confirmLabel: 'Remove',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    setState(() {
      _isSaving = true;
      _saveFailed = false;
      _saveMessage = 'Removing load from Central…';
    });

    final outcome = await AppStateScope.of(
      context,
    ).removeLoad(nodeMac: load.owningNodeMac, relayPin: load.relayPin);

    if (!mounted) return;
    if (outcome.isConfirmed) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _isSaving = false;
      _saveFailed = true;
      _saveMessage = outcome.message ?? 'Central rejected this command.';
    });
  }

  Future<void> _editConfiguration(LoadModel load) async {
    final draft = await showLoadConfigurationDialog(context, load: load);
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
      currentRequestedState: load.requestedState ?? false,
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
        final matches = loads.where(
          (candidate) => candidate.id == widget.load.id,
        );
        final load = matches.isEmpty ? widget.load : matches.first;
        final priorityLevel = LoadPriorityLevel.bucketFor(load.priority);

        return Scaffold(
          appBar: AppBar(title: Text(load.name)),
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
                            : 'GPIO ${load.relayPin} · ${load.owningNodeMac}',
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
                            child: LoadStateControl(load: load),
                          ),
                          SectionCard(
                            title: 'Configuration',
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
                                  label: 'Schedule',
                                  value: load.schedule.enabled
                                      ? _scheduleLabel(load.schedule)
                                      : 'Not scheduled',
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Wrap(
                                  alignment: WrapAlignment.end,
                                  spacing: AppSpacing.sm,
                                  runSpacing: AppSpacing.xs,
                                  children: [
                                    TextButton.icon(
                                      onPressed: _isSaving
                                          ? null
                                          : () => _removeLoad(load),
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppColors.error,
                                      ),
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        size: 18,
                                      ),
                                      label: const Text('Remove load'),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: _isSaving
                                          ? null
                                          : () => _editConfiguration(load),
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        size: 18,
                                      ),
                                      label: Text(
                                        _isSaving
                                            ? 'Applying…'
                                            : 'Edit configuration',
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      SectionCard(
                        title: 'Planning data',
                        child: Column(
                          children: [
                            SectionRow(
                              label: 'Rated power',
                              value: Formatters.power(load.ratedPowerW),
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
                              label: 'Last update',
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
