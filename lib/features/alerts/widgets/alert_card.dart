import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../models/alert_model.dart';

class AlertCard extends StatelessWidget {
  const AlertCard({required this.alert, super.key, this.compact = false});

  final AlertModel alert;
  final bool compact;

  (IconData, Color) get _severityStyle {
    switch (alert.severity) {
      case AlertSeverity.critical:
        return (Icons.error_rounded, AppColors.error);
      case AlertSeverity.warning:
        return (Icons.warning_rounded, AppColors.warning);
      case AlertSeverity.info:
        return (Icons.info_rounded, AppColors.info);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _severityStyle;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: alert.acknowledged
            ? AppColors.surface
            : color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: alert.acknowledged
              ? AppColors.border
              : color.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(alert.title, style: AppTextStyles.label),
                if (!compact) ...[
                  const SizedBox(height: 2),
                  Text(alert.message, style: AppTextStyles.caption),
                ],
                const SizedBox(height: 2),
                Text(
                  Formatters.relativeTime(alert.timestamp),
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
