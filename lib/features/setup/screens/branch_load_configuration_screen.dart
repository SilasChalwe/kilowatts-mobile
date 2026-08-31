import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/primary_button.dart';
import '../../system/models/topology_model.dart';
import '../models/setup_session.dart';
import '../widgets/branch_assignment_card.dart';
import '../widgets/setup_progress_indicator.dart';
import 'schedule_configuration_screen.dart';

/// Lets the user name and prioritize the Loads Central has already
/// discovered. Relay identity (owning node + pin) always comes from the
/// topology payload — the user can never invent a channel here.
class BranchLoadConfigurationScreen extends StatelessWidget {
  const BranchLoadConfigurationScreen({required this.setupSession, super.key});

  final SetupSession setupSession;

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Load Assignment')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SetupProgressIndicator(step: 4, title: 'Load Assignment'),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: ValueListenableBuilder<TopologyModel?>(
                  valueListenable: appState.topology,
                  builder: (context, topology, _) {
                    if (topology == null) {
                      return const LoadingIndicator();
                    }
                    final entries = [
                      for (final node in topology.nodes)
                        for (final load in node.loads) (node: node, load: load),
                    ];
                    if (entries.isEmpty) {
                      return const EmptyState(
                        icon: Icons.electrical_services_outlined,
                        title: 'No Loads Detected Yet',
                      );
                    }

                    return ListView(
                      children: [
                        for (final entry in entries) ...[
                          Builder(
                            builder: (context) {
                              final nodeLabel =
                                  setupSession.nodeNames[entry.node.mac] ??
                                  entry.node.displayName;
                              final draft = setupSession.draftFor(
                                entry.load.owningNodeMac,
                                entry.load.relayPin,
                                entry.load.name.isEmpty
                                    ? '$nodeLabel Load'
                                    : entry.load.name,
                              );
                              return Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.md,
                                ),
                                child: BranchAssignmentCard(
                                  draft: draft,
                                  loadLabel:
                                      '$nodeLabel · Relay ${entry.load.relayPin}',
                                ),
                              );
                            },
                          ),
                        ],
                      ],
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
                        ScheduleConfigurationScreen(setupSession: setupSession),
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
