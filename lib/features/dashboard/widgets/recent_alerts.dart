import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
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
      title: 'Recent alerts',
      trailing: alerts.isEmpty
          ? null
          : TextButton(onPressed: onViewAll, child: const Text('View all')),
      child: alerts.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    color: AppColors.success,
                    size: 20,
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('No active alerts', style: AppTextStyles.label),
                        SizedBox(height: 2),
                        Text(
                          'Everything reported by the system looks normal.',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                ],
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
