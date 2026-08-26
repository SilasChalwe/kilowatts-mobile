import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

class SectionCard extends StatelessWidget {
  const SectionCard({
    required this.child,
    super.key,
    this.title,
    this.trailing,
    this.padding = const EdgeInsets.all(AppSpacing.md),
  });

  final String? title;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    title!,
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          child,
        ],
      ),
    );
  }
}

class SectionRow extends StatelessWidget {
  const SectionRow({
    required this.label,
    super.key,
    this.value,
    this.valueWidget,
    this.onTap,
  });

  final String label;
  final String? value;
  final Widget? valueWidget;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          if (valueWidget != null)
            Flexible(
              child: Align(
                alignment: Alignment.centerRight,
                child: valueWidget!,
              ),
            )
          else
            Flexible(
              child: Text(
                value ?? '—',
                textAlign: TextAlign.end,
                softWrap: true,
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          if (onTap != null) ...[
            const SizedBox(width: AppSpacing.xxs),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return row;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      onTap: onTap,
      child: row,
    );
  }
}
