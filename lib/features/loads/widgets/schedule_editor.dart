import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../models/load_model.dart';

/// Editable "not eligible before this time" deferment. Priority still
/// decides importance — this only controls when a load becomes eligible;
/// it never forces a load ON at the given time.
class ScheduleEditor extends StatelessWidget {
  const ScheduleEditor({
    required this.schedule,
    required this.onChanged,
    super.key,
  });

  final LoadSchedule schedule;
  final ValueChanged<LoadSchedule> onChanged;

  Future<void> _pickTime(BuildContext context) async {
    final initial = TimeOfDay(
      hour: schedule.hour ?? 6,
      minute: schedule.minute ?? 0,
    );
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;

    onChanged(
      LoadSchedule(
        enabled: schedule.enabled,
        hour: picked.hour,
        minute: picked.minute,
      ),
    );
  }

  void _toggleEnabled(bool enabled) {
    onChanged(
      LoadSchedule(
        enabled: enabled,
        hour: schedule.hour ?? 6,
        minute: schedule.minute ?? 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Schedule Enabled', style: AppTextStyles.label),
            ),
            Switch(value: schedule.enabled, onChanged: _toggleEnabled),
          ],
        ),
        if (schedule.enabled) ...[
          const SizedBox(height: AppSpacing.xs),
          OutlinedButton(
            onPressed: () => _pickTime(context),
            child: Text(
              schedule.hour == null
                  ? 'Eligible from…'
                  : 'Eligible from ${Formatters.timeOfDay(schedule.hour!, schedule.minute ?? 0)}',
            ),
          ),
        ] else
          const Padding(
            padding: EdgeInsets.only(top: AppSpacing.xxs),
            child: Text(
              'Not before any particular time — priority alone decides scheduling.',
              style: AppTextStyles.caption,
            ),
          ),
      ],
    );
  }
}
