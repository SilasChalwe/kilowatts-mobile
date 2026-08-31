import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_card.dart';
import '../../alerts/models/alert_model.dart';
import '../../alerts/widgets/alert_card.dart';

class RecentAlerts extends StatelessWidget {
  const RecentAlerts({required this.alerts, super.key, this.onViewAll});

  final List<AlertModel> alerts;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Recent Alerts',
      trailing: alerts.isEmpty
          ? null
          : TextButton(onPressed: onViewAll, child: const Text('View all')),
      child: alerts.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: EmptyState(
                icon: Icons.check_circle_outline,
                title: 'No Active Alerts',
              ),
            )
          : Column(
              children: [
                for (final alert in alerts.take(3)) ...[
                  AlertCard(alert: alert, compact: true),
                  const SizedBox(height: AppSpacing.xs),
                ],
              ],
            ),
    );
  }
}
