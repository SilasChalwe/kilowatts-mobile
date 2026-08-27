import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/load_model.dart';
import 'load_mode_selector.dart';
import 'priority_selector.dart';
import 'schedule_editor.dart';

class LoadConfigurationDraft {
  const LoadConfigurationDraft({
    required this.mode,
    required this.priority,
    required this.schedule,
  });

  final LoadMode mode;
  final int priority;
  final LoadSchedule schedule;
}

Future<LoadConfigurationDraft?> showLoadConfigurationDialog(
  BuildContext context, {
  required LoadModel load,
}) {
  return showDialog<LoadConfigurationDraft>(
    context: context,
    builder: (_) => _LoadConfigurationDialog(load: load),
  );
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
      LoadConfigurationDraft(
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
              const SizedBox(height: AppSpacing.xs),
              PrioritySelector(
                value: _priority,
                onChanged: (value) => setState(() => _priority = value),
              ),
              if (_mode == LoadMode.auto) ...[
                const SizedBox(height: AppSpacing.lg),
                const Text('Schedule', style: AppTextStyles.label),
                const SizedBox(height: AppSpacing.xs),
                ScheduleEditor(
                  schedule: _schedule,
                  onChanged: (value) => setState(() => _schedule = value),
                ),
              ] else ...[
                const SizedBox(height: AppSpacing.lg),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: const Text(
                    'Fixed loads use manual ON/OFF control. Automatic scheduling is disabled.',
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
        FilledButton(onPressed: _apply, child: const Text('Save changes')),
      ],
    );
  }
}
