import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/status_badge.dart';
import '../../system/models/node_model.dart';
import '../../system/models/topology_model.dart';
import '../models/setup_session.dart';
import '../widgets/discovered_node_card.dart';
import '../widgets/setup_progress_indicator.dart';
import 'node_configuration_screen.dart';
import 'safety_configuration_screen.dart';

/// Central discovers Smart Nodes over ESP-NOW and publishes the result on
/// `kilowatts/v1/state/tree`. This screen only ever shows what Central has
/// already found — the app never performs discovery itself.
class DiscoveredNodesScreen extends StatelessWidget {
  const DiscoveredNodesScreen({required this.setupSession, super.key});

  final SetupSession setupSession;

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Discovered Devices')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SetupProgressIndicator(
                step: 2,
                title: 'Discovered Devices',
              ),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: ValueListenableBuilder<TopologyModel?>(
                  valueListenable: appState.topology,
                  builder: (context, topology, _) {
                    if (topology == null) {
                      return const LoadingIndicator(
                        message:
                            'Waiting for the Central Node to report its devices…',
                      );
                    }
                    if (topology.smartNodes.isEmpty) {
                      return const EmptyState(
                        icon: Icons.wifi_tethering_error_rounded,
                        title: 'No Smart Nodes Found Yet',
                        message:
                            'Power on your Smart Nodes and keep them near the Central Node.',
                      );
                    }

                    return ListView(
                      children: [
                        Text('Central', style: AppTextStyles.label),
                        const SizedBox(height: AppSpacing.xs),
                        DiscoveredNodeCard(
                          node:
                              topology.central ??
                              const NodeModel(
                                mac: '',
                                role: NodeRole.central,
                                online: false,
                              ),
                          branchCount: topology.central == null
                              ? 0
                              : topology
                                    .branchesOf(topology.central!.mac)
                                    .length,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text('Smart Nodes', style: AppTextStyles.label),
                        const SizedBox(height: AppSpacing.xs),
                        for (final node in topology.smartNodes) ...[
                          DiscoveredNodeCard(
                            node: node,
                            branchCount: topology.branchesOf(node.mac).length,
                            isConfigured: setupSession.nodeNames.containsKey(
                              node.mac,
                            ),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => NodeConfigurationScreen(
                                  node: node,
                                  setupSession: setupSession,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              ValueListenableBuilder<TopologyModel?>(
                valueListenable: appState.topology,
                builder: (context, topology, _) {
                  final total = topology?.smartNodes.length ?? 0;
                  final configured = setupSession.nodeNames.length;
                  return Column(
                    children: [
                      if (total > 0)
                        StatusBadge(
                          label: '$configured of $total named',
                          tone: configured == total
                              ? StatusTone.positive
                              : StatusTone.neutral,
                          showDot: false,
                        ),
                      const SizedBox(height: AppSpacing.sm),
                      PrimaryButton(
                        label: 'Continue',
                        onPressed: total == 0
                            ? null
                            : () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => SafetyConfigurationScreen(
                                    setupSession: setupSession,
                                  ),
                                ),
                              ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
