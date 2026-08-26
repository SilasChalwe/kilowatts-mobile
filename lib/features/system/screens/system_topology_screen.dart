import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/metric_card.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/responsive_content.dart';
import '../../../core/widgets/section_card.dart';
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
              final hasTopology = topology?.central != null;
              final smartNodes = topology?.smartNodes ?? const [];
              final onlineNodes = smartNodes.where((node) => node.online).length;

              return ListView(
                children: [
                  ResponsiveContent(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PageHeader(
                          title: 'System',
                          subtitle: hasTopology
                              ? 'Communication topology and configured load ownership for this installation.'
                              : 'Installation topology will appear after Central publishes its first report.',
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        if (!hasTopology)
                          const EmptyState(
                            icon: Icons.hub_outlined,
                            title: 'Topology unavailable',
                            message:
                                'Central has not reported a topology yet. Check that it is powered on and connected to the broker.',
                          )
                        else ...[
                          ResponsiveCardGrid(
                            minCardWidth: 220,
                            maxColumns: 3,
                            children: [
                              MetricCard(
                                label: 'Central node',
                                value: topology!.central!.online ? 'Online' : 'Offline',
                                icon: Icons.memory_outlined,
                                valueColor: topology.central!.online
                                    ? AppColors.success
                                    : AppColors.error,
                              ),
                              MetricCard(
                                label: 'Smart nodes online',
                                value: '$onlineNodes/${smartNodes.length}',
                                icon: Icons.device_hub_outlined,
                              ),
                              MetricCard(
                                label: 'Configured loads',
                                value: '${loads.length}',
                                icon: Icons.electrical_services_outlined,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          SectionCard(
                            title: 'Installation topology',
                            subtitle:
                                'Select any node or load to inspect its current details.',
                            child: SizedBox(
                              height: MediaQuery.sizeOf(context).width < 700 ? 430 : 520,
                              child: GraphicalTopologyTree(
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
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
