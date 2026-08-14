import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/section_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../../system/models/node_model.dart';

/// Read-only identity/diagnostic details for a discovered Node. The user
/// can rename the node elsewhere on the same screen, but everything here —
/// MAC, role, hop count, last seen — reflects what Central actually
/// reported and cannot be edited.
class NodeConfigurationCard extends StatelessWidget {
  const NodeConfigurationCard({required this.node, super.key});

  final NodeModel node;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Device Details',
      child: Column(
        children: [
          SectionRow(
            label: 'Node MAC',
            value: node.mac.isEmpty ? '—' : node.mac,
          ),
          SectionRow(
            label: 'Role',
            value: node.role == NodeRole.central
                ? 'Central Node'
                : 'Smart Node',
          ),
          SectionRow(
            label: 'Status',
            valueWidget: StatusBadge.online(online: node.online),
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
    );
  }
}
