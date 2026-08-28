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

  /// Kept for source compatibility. When enabled the badge now shows a
  /// tone-specific icon instead of a colour-only dot.
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

  IconData get _icon {
    switch (tone) {
      case StatusTone.positive:
        return Icons.check_circle_outline_rounded;
      case StatusTone.negative:
        return Icons.cancel_outlined;
      case StatusTone.warning:
        return Icons.warning_amber_rounded;
      case StatusTone.info:
        return Icons.info_outline_rounded;
      case StatusTone.neutral:
        return Icons.remove_circle_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Semantics(
      container: true,
      label: label,
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 5,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: color.withValues(alpha: 0.18)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showDot) ...[
                Icon(_icon, size: 13, color: color),
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
        ),
      ),
    );
  }
}
