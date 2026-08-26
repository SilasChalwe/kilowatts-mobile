import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../models/load_model.dart';

/// Edits the preferred running window used by the firmware's AUTO planner.
/// Priority still decides importance; the window only changes when the load
/// is eligible for the preference boost and never forces a load ON.
class ScheduleEditor extends StatelessWidget {
  const ScheduleEditor({
    required this.schedule,
    required this.onChanged,
    super.key,
  });

  final LoadSchedule schedule;
  final ValueChanged<LoadSchedule> onChanged;

  Future<void> _pickStart(BuildContext context) async {
    final initial = TimeOfDay(
      hour: schedule.startHour ?? 6,
      minute: schedule.startMinute ?? 0,
    );
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;

    final endHour = schedule.endHour ?? ((picked.hour + 1) % 24);
    final endMinute = schedule.endMinute ?? picked.minute;
    onChanged(
      LoadSchedule(
        enabled: schedule.enabled,
        startHour: picked.hour,
        startMinute: picked.minute,
        endHour: endHour,
        endMinute: endMinute,
      ),
    );
  }

  Future<void> _pickEnd(BuildContext context) async {
    final startHour = schedule.startHour ?? 6;
    final startMinute = schedule.startMinute ?? 0;
    final initial = TimeOfDay(
      hour: schedule.endHour ?? ((startHour + 1) % 24),
      minute: schedule.endMinute ?? startMinute,
    );
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;

    if (picked.hour == startHour && picked.minute == startMinute) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Start and end time must be different.')),
      );
      return;
    }

    onChanged(
      LoadSchedule(
        enabled: schedule.enabled,
        startHour: startHour,
        startMinute: startMinute,
        endHour: picked.hour,
        endMinute: picked.minute,
      ),
    );
  }

  void _toggleEnabled(bool enabled) {
    final startHour = schedule.startHour ?? 6;
    final startMinute = schedule.startMinute ?? 0;
    onChanged(
      LoadSchedule(
        enabled: enabled,
        startHour: startHour,
        startMinute: startMinute,
        endHour: schedule.endHour ?? ((startHour + 1) % 24),
        endMinute: schedule.endMinute ?? startMinute,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final startHour = schedule.startHour ?? 6;
    final startMinute = schedule.startMinute ?? 0;
    final endHour = schedule.endHour ?? ((startHour + 1) % 24);
    final endMinute = schedule.endMinute ?? startMinute;

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
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              OutlinedButton.icon(
                onPressed: () => _pickStart(context),
                icon: const Icon(Icons.play_arrow_outlined),
                label: Text(
                  'Start ${Formatters.timeOfDay(startHour, startMinute)}',
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _pickEnd(context),
                icon: const Icon(Icons.stop_outlined),
                label: Text('End ${Formatters.timeOfDay(endHour, endMinute)}'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          const Text(
            'Overnight windows are supported, for example 22:00–02:00.',
            style: AppTextStyles.caption,
          ),
        ] else
          const Padding(
            padding: EdgeInsets.only(top: AppSpacing.xxs),
            child: Text(
              'No preferred running window — priority and available power decide scheduling.',
              style: AppTextStyles.caption,
            ),
          ),
      ],
    );
  }
}
