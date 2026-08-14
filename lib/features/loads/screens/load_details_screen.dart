import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../../core/services/command_outcome.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
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
  String? _saveError;

  Future<void> _saveConfiguration() async {
    setState(() {
      _isSaving = true;
      _saveError = null;
    });

    final outcome = await AppStateScope.of(context).updateLoadConfiguration(
      nodeMac: widget.load.owningNodeMac,
      relayPin: widget.load.relayPin,
      mode: _mode,
      currentRequestedState:
          widget.load.requestedState ?? widget.load.confirmedState ?? false,
      priority: _priority,
      schedule: _schedule,
    );

    if (!mounted) return;
    setState(() {
      _isSaving = false;
      _saveError = outcome.status == CommandStatus.failed
          ? outcome.message
          : null;
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

        return Scaffold(
          appBar: AppBar(title: Text(load.name)),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                SectionCard(
                  title: 'Load Info',
                  trailing: StatusBadge(
                    label: load.available ? 'Available' : 'Unavailable',
                    tone: load.available
                        ? StatusTone.positive
                        : StatusTone.negative,
                  ),
                  child: Column(
                    children: [
                      SectionRow(
                        label: 'Owning Node',
                        value: load.owningNodeName ?? load.owningNodeMac,
                      ),
                      SectionRow(
                        label: 'Relay Channel',
                        value: '${load.relayPin}',
                      ),
                      SectionRow(
                        label: 'Last Updated',
                        value: Formatters.relativeTime(load.lastUpdated),
                      ),
                      if (load.confirmedState != null &&
                          !load.confirmedStateValid)
                        const SectionRow(
                          label: 'Confirmation',
                          valueWidget: StatusBadge(
                            label: 'Unconfirmed',
                            tone: StatusTone.warning,
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
                  title: 'Planning Rating',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionRow(
                        label: 'Planned Running Power',
                        value: Formatters.power(load.plannedPowerW),
                      ),
                      SectionRow(
                        label: 'Rated Voltage',
                        value: load.ratedVoltageV == null
                            ? 'Unavailable'
                            : '${load.ratedVoltageV!.toStringAsFixed(1)} V',
                      ),
                      SectionRow(
                        label: 'Rated Current',
                        value: load.ratedCurrentA == null
                            ? 'Unavailable'
                            : '${load.ratedCurrentA!.toStringAsFixed(2)} A',
                      ),
                      SectionRow(
                        label: 'Startup Power',
                        value: Formatters.power(load.startupPowerW),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      const Text(
                        'These are installer ratings used for planning. This system does not measure individual load consumption live.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                SectionCard(
                  title: 'Configuration',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Mode',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      LoadModeSelector(
                        value: _mode,
                        onChanged: (v) => setState(() => _mode = v),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      const Text(
                        'Priority',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      PrioritySelector(
                        value: _priority,
                        onChanged: (v) => setState(() => _priority = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                SectionCard(
                  title: 'Schedule',
                  child: ScheduleEditor(
                    schedule: _schedule,
                    onChanged: (s) => setState(() => _schedule = s),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                PrimaryButton(
                  label: 'Save Configuration',
                  isLoading: _isSaving,
                  onPressed: _saveConfiguration,
                ),
                if (_saveError != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _saveError!,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 12,
                    ),
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
