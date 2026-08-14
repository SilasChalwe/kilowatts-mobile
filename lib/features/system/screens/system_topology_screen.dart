import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../loads/models/load_model.dart';
import '../../loads/screens/load_details_screen.dart';
import '../models/topology_model.dart';
import '../widgets/topology_tree.dart';
import 'node_details_screen.dart';

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
                  if (topology == null) {
                    return const LoadingIndicator(
                      message: 'Loading system topology…',
                    );
                  }
                  if (topology.central == null) {
                    return const EmptyState(
                      icon: Icons.hub_outlined,
                      title: 'Central Node Not Found',
                      message:
                          'Check that your Central Node is powered on and connected.',
                    );
                  }

                  return ValueListenableBuilder<List<LoadModel>>(
                    valueListenable: appState.loads,
                    builder: (context, loads, _) {
                      return SingleChildScrollView(
                        child: TopologyTree(
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
