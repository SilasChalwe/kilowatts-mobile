import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

enum StatusTone { positive, negative, warning, info, neutral }

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    required this.label,
    super.key,
    this.tone = StatusTone.neutral,
    this.showDot = true,
  });

  factory StatusBadge.online({bool online = true}) => StatusBadge(
    label: online ? 'Online' : 'Offline',
    tone: online ? StatusTone.positive : StatusTone.negative,
  );

  final String label;
  final StatusTone tone;
  final bool showDot;

  Color get _color {
    switch (tone) {
      case StatusTone.positive:
        return AppColors.success;
      case StatusTone.negative:
        return AppColors.error;
      case StatusTone.warning:
        return AppColors.warning;
      case StatusTone.info:
        return AppColors.info;
      case StatusTone.neutral:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: AppSpacing.xxs),
          ],
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
