import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/services/mqtt_service.dart' show MqttConnectionStatus;
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/section_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../../system/models/topology_model.dart';
import '../models/setup_session.dart';
import '../widgets/setup_progress_indicator.dart';

class SetupSummaryScreen extends StatefulWidget {
  const SetupSummaryScreen({required this.setupSession, super.key});

  final SetupSession setupSession;

  @override
  State<SetupSummaryScreen> createState() => _SetupSummaryScreenState();
}

class _SetupSummaryScreenState extends State<SetupSummaryScreen> {
  bool _isFinishing = false;
  String? _warning;

  Future<void> _finish() async {
    setState(() {
      _isFinishing = true;
      _warning = null;
    });

    final appState = AppStateScope.of(context);
    var failureCount = 0;

    final safetyOutcome = await appState.applySafetyConfig(
      widget.setupSession.safety,
    );
    if (!safetyOutcome.isConfirmed) failureCount++;

    for (final draft in widget.setupSession.loadDrafts.values) {
      final outcome = await appState.updateLoadConfiguration(
        nodeMac: draft.owningNodeMac,
        relayPin: draft.relayPin,
        mode: draft.mode,
        currentRequestedState: false,
        priority: draft.priority,
        schedule: draft.schedule,
      );
      if (!outcome.isConfirmed) failureCount++;
    }

    if (!mounted) return;

    if (failureCount > 0) {
      setState(() {
        _isFinishing = false;
        _warning =
            '$failureCount setting${failureCount == 1 ? '' : 's'} could not be confirmed by the Central Node yet. '
            'Setup has not been marked complete. Correct the failed commands and try again.';
      });
      return;
    }

    await appState.setSetupComplete(true);
    if (!mounted) return;

    Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.root, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Setup Complete')),
      body: SafeArea(
        child: ValueListenableBuilder<TopologyModel?>(
          valueListenable: appState.topology,
          builder: (context, topologyValue, _) {
            final topology = topologyValue ?? TopologyModel.empty;
            final loadCount = widget.setupSession.loadDrafts.length;
            final scheduleCount = widget.setupSession.loadDrafts.values
                .where((d) => d.schedule.enabled)
                .length;

            return ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                const SetupProgressIndicator(step: 7, title: 'Setup Summary'),
                const SizedBox(height: AppSpacing.lg),
                const Icon(
                  Icons.check_circle_outline,
                  size: 56,
                  color: AppColors.success,
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'Your system is ready',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.title,
                ),
                const SizedBox(height: AppSpacing.lg),
                SectionCard(
                  child: Column(
                    children: [
                      SectionRow(
                        label: 'Central Connection',
                        valueWidget: StatusBadge.online(
                          online: topology.central?.online ?? false,
                        ),
                      ),
                      SectionRow(
                        label: 'Smart Nodes Detected',
                        value: '${topology.smartNodes.length}',
                      ),
                      SectionRow(
                        label: 'Smart Nodes Named',
                        value: '${widget.setupSession.nodeNames.length}',
                      ),
                      SectionRow(
                        label: 'Loads Detected',
                        value:
                            '${topology.nodes.fold<int>(0, (sum, n) => sum + n.loads.length)}',
                      ),
                      SectionRow(
                        label: 'Loads Configured',
                        value: '$loadCount',
                      ),
                      const SectionRow(
                        label: 'Safety Thresholds',
                        value: 'Configured',
                      ),
                      SectionRow(label: 'Schedules', value: '$scheduleCount'),
                      ValueListenableBuilder<MqttConnectionStatus>(
                        valueListenable: appState.connectionStatus,
                        builder: (context, status, _) {
                          final connected =
                              status == MqttConnectionStatus.connected;
                          return SectionRow(
                            label: 'MQTT Connectivity',
                            valueWidget: StatusBadge(
                              label: connected ? 'Connected' : 'Unavailable',
                              tone: connected
                                  ? StatusTone.positive
                                  : StatusTone.warning,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                if (_warning != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _warning!,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.warning,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                PrimaryButton(
                  label: 'Finish Setup',
                  isLoading: _isFinishing,
                  onPressed: _finish,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
