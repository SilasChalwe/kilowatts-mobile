import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

class OverviewKpiCard extends StatelessWidget {
  const OverviewKpiCard({
    required this.label,
    required this.value,
    required this.icon,
    super.key,
    this.supportingText,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? supportingText;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: supportingText == null
          ? '$label, $value'
          : '$label, $value, $supportingText',
      child: Container(
        constraints: const BoxConstraints(minHeight: 112),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(icon, size: 17, color: AppColors.primary),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    label,
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              value,
              style: AppTextStyles.pageTitle.copyWith(fontSize: 24),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (supportingText != null) ...[
              const SizedBox(height: 2),
              Text(
                supportingText!,
                style: AppTextStyles.caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
