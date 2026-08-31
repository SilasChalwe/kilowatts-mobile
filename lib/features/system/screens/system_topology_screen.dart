import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../loads/models/load_model.dart';
import '../../loads/screens/load_details_screen.dart';
import '../models/topology_model.dart';
import '../widgets/graphical_topology_tree.dart';
import 'node_details_screen.dart';

class SystemTopologyScreen extends StatelessWidget {
  const SystemTopologyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);

    return SafeArea(
      child: ValueListenableBuilder<TopologyModel?>(
        valueListenable: appState.topology,
        builder: (context, topology, _) {
          return ValueListenableBuilder<List<LoadModel>>(
            valueListenable: appState.loads,
            builder: (context, loads, _) {
              final currentTopology = topology;
              final hasTopology = currentTopology?.central != null;

              if (!hasTopology) {
                return const Center(
                  child: EmptyState(
                    icon: Icons.home_work_outlined,
                    title: 'House topology unavailable',
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: SizedBox.expand(
                  child: GraphicalTopologyTree(
                    topology: currentTopology!,
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
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
