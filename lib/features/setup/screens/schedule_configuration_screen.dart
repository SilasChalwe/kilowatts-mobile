import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/section_card.dart';
import '../../loads/widgets/schedule_editor.dart';
import '../models/setup_session.dart';
import '../widgets/setup_progress_indicator.dart';
import 'setup_summary_screen.dart';

class ScheduleConfigurationScreen extends StatefulWidget {
  const ScheduleConfigurationScreen({required this.setupSession, super.key});

  final SetupSession setupSession;

  @override
  State<ScheduleConfigurationScreen> createState() =>
      _ScheduleConfigurationScreenState();
}

class _ScheduleConfigurationScreenState
    extends State<ScheduleConfigurationScreen> {
  @override
  Widget build(BuildContext context) {
    final drafts = widget.setupSession.loadDrafts.values.toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Schedules')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SetupProgressIndicator(step: 5, title: 'Schedules'),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: drafts.isEmpty
                    ? const EmptyState(
                        icon: Icons.event_busy_outlined,
                        title: 'No Loads to Schedule',
                        message: 'Go back and assign loads first.',
                      )
                    : ListView.separated(
                        itemCount: drafts.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) {
                          final draft = drafts[index];
                          return SectionCard(
                            title: draft.name,
                            child: ScheduleEditor(
                              schedule: draft.schedule,
                              onChanged: (schedule) =>
                                  setState(() => draft.schedule = schedule),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: AppSpacing.sm),
              PrimaryButton(
                label: 'Continue',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        SetupSummaryScreen(setupSession: widget.setupSession),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
