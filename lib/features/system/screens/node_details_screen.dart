import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../../loads/models/load_model.dart';
import '../../loads/screens/load_details_screen.dart';
import '../models/node_model.dart';
import '../models/topology_model.dart';
import '../widgets/branch_card.dart';
import '../widgets/node_health_card.dart';

class NodeDetailsScreen extends StatelessWidget {
  const NodeDetailsScreen({required this.node, super.key});

  final NodeModel node;

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(node.displayName)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            SectionCard(
              title: 'Identity & Communication',
              trailing: StatusBadge.online(online: node.online),
              child: Column(
                children: [
                  SectionRow(
                    label: 'MAC',
                    value: node.mac.isEmpty ? null : node.mac,
                  ),
                  SectionRow(
                    label: 'Role',
                    value: node.role == NodeRole.central
                        ? 'Central Node'
                        : 'Smart Node',
                  ),
                  SectionRow(
                    label: 'Next Hop',
                    value: node.nextHopMac == null || node.nextHopMac!.isEmpty
                        ? 'Central (direct)'
                        : node.nextHopMac,
                  ),
                  SectionRow(
                    label: 'Hop Count',
                    value: Formatters.hopCount(node.hopCount),
                  ),
                  SectionRow(
                    label: 'Last Seen',
                    value: Formatters.relativeTime(node.lastSeen),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            NodeHealthCard(diagnostics: node.diagnostics),
            const SizedBox(height: AppSpacing.md),
            ValueListenableBuilder<TopologyModel?>(
              valueListenable: appState.topology,
              builder: (context, topology, _) {
                final branches = topology?.branchesOf(node.mac) ?? const [];
                return ValueListenableBuilder<List<LoadModel>>(
                  valueListenable: appState.loads,
                  builder: (context, loads, _) {
                    return SectionCard(
                      title: 'Local Branches / Loads',
                      child: branches.isEmpty
                          ? const EmptyState(
                              icon: Icons.electrical_services_outlined,
                              title: 'No Branches Reported',
                            )
                          : Column(
                              children: [
                                for (final branch in branches) ...[
                                  Builder(
                                    builder: (context) {
                                      LoadModel? load;
                                      for (final candidate in loads) {
                                        if (candidate.owningNodeMac ==
                                                branch.owningNodeMac &&
                                            candidate.relayPin ==
                                                branch.relayPin) {
                                          load = candidate;
                                        }
                                      }
                                      return BranchCard(
                                        branch: branch,
                                        loadName: load?.name,
                                        onTap: load == null
                                            ? null
                                            : () => Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      LoadDetailsScreen(
                                                        load: load!,
                                                      ),
                                                ),
                                              ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                ],
                              ],
                            ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
