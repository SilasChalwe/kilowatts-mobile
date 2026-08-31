import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/responsive_content.dart';
import '../../../core/widgets/section_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../../loads/screens/load_details_screen.dart';
import '../models/node_model.dart';
import '../models/topology_model.dart';
import '../widgets/node_health_card.dart';
import '../widgets/node_load_row.dart';

class NodeDetailsScreen extends StatelessWidget {
  const NodeDetailsScreen({required this.node, super.key});

  final NodeModel node;

  Widget _identityCard() {
    return SectionCard(
      title: 'Identity & communication',
      child: Column(
        children: [
          SectionRow(
            label: 'MAC address',
            value: node.mac.isEmpty ? null : node.mac,
          ),
          SectionRow(
            label: 'Role',
            value: node.role == NodeRole.central
                ? 'Central node'
                : 'Smart node',
          ),
          SectionRow(
            label: 'Next hop',
            value: node.nextHopMac == null || node.nextHopMac!.isEmpty
                ? 'Central · direct'
                : node.nextHopMac,
          ),
          SectionRow(
            label: 'Hop count',
            value: Formatters.hopCount(node.hopCount),
          ),
          SectionRow(
            label: 'Last seen',
            value: Formatters.relativeTime(node.lastSeen),
          ),
        ],
      ),
    );
  }

  Widget _loads(BuildContext context) {
    final appState = AppStateScope.of(context);
    return ValueListenableBuilder<TopologyModel?>(
      valueListenable: appState.topology,
      builder: (context, topology, _) {
        final loads = topology?.nodeByMac(node.mac)?.loads ?? const [];
        return SectionCard(
          title: 'Connected loads',
          child: loads.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Row(
                    children: [
                      Icon(
                        Icons.electrical_services_outlined,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                      SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'No loads reported',
                              style: AppTextStyles.label,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    for (var index = 0; index < loads.length; index++) ...[
                      NodeLoadRow(
                        load: loads[index],
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                LoadDetailsScreen(load: loads[index]),
                          ),
                        ),
                      ),
                      if (index != loads.length - 1)
                        const SizedBox(height: AppSpacing.xs),
                    ],
                  ],
                ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Node details')),
      body: SafeArea(
        child: ListView(
          children: [
            ResponsiveContent(
              maxWidth: 1120,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PageHeader(
                    eyebrow: node.role == NodeRole.central
                        ? 'Central node'
                        : 'Smart node',
                    title: node.displayName,
                    subtitle: node.mac,
                    actions: [StatusBadge.online(online: node.online)],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  ResponsiveCardGrid(
                    minCardWidth: 360,
                    maxColumns: 2,
                    children: [
                      _identityCard(),
                      NodeHealthCard(diagnostics: node.diagnostics),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _loads(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
