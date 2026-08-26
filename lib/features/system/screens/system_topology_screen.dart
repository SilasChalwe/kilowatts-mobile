import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/page_header.dart';
import '../../loads/models/load_model.dart';
import '../../loads/screens/load_details_screen.dart';
import '../models/topology_model.dart';
import '../widgets/graphical_topology_tree.dart';
import 'node_details_screen.dart';

class SystemTopologyScreen extends StatelessWidget {
  const SystemTopologyScreen({super.key, this.embedded = false});

  final bool embedded;

  Widget _content(BuildContext context, {required bool showPageHeader}) {
    final appState = AppStateScope.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showPageHeader) ...[
            const PageHeader(
              title: 'System',
              subtitle: 'Central node, smart nodes and connected loads.',
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          Expanded(
            child: ValueListenableBuilder<TopologyModel?>(
              valueListenable: appState.topology,
              builder: (context, topology, _) {
                if (topology == null || topology.central == null) {
                  return const EmptyState(
                    compact: true,
                    icon: Icons.hub_outlined,
                    title: 'System not discovered yet',
                    message:
                        'Connect Central and wait for its topology update. Nodes and loads will appear here automatically.',
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
    );
  }

  @override
  Widget build(BuildContext context) {
    if (embedded) {
      return Material(
        color: Colors.transparent,
        child: SafeArea(child: _content(context, showPageHeader: true)),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('System')),
      body: SafeArea(child: _content(context, showPageHeader: false)),
    );
  }
}
