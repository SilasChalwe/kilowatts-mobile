import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/empty_state.dart';
import '../../loads/models/load_model.dart';
import '../../loads/screens/load_details_screen.dart';
import '../models/topology_model.dart';
import '../widgets/graphical_topology_tree.dart';
import 'node_details_screen.dart';

/// Shared by both the homeowner mobile app (bottom nav) and the installer
/// Web portal - one screen, one graphical tree, so both surfaces always
/// show the same topology rather than two implementations drifting apart.
class SystemTopologyScreen extends StatelessWidget {
  const SystemTopologyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('System Topology', style: AppTextStyles.title),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: ValueListenableBuilder<TopologyModel?>(
                valueListenable: appState.topology,
                builder: (context, topology, _) {
                  // No spinner: either there is a tree to draw, or there is
                  // not - a perpetual loading state when nothing has ever
                  // arrived is not honest about what is actually known.
                  if (topology == null || topology.central == null) {
                    return const EmptyState(
                      icon: Icons.hub_outlined,
                      title: 'No Topology Data',
                      message:
                          'Central has not reported a topology yet. Check that it is powered on and connected.',
                    );
                  }

                  return ValueListenableBuilder<List<LoadModel>>(
                    valueListenable: appState.loads,
                    builder: (context, loads, _) {
                      return GraphicalTopologyTree(
                        topology: topology,
                        loads: loads,
                        onNodeTap: (node) => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => NodeDetailsScreen(node: node),
                          ),
                        ),
                        onLoadTap: (load) => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => LoadDetailsScreen(load: load),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
