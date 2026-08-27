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

  /// Kept for source compatibility with the original component API. The
  /// visual cue is now a tone-specific icon rather than a color-only dot.
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
        return Icons.circle_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Semantics(
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 5,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showDot) ...[
              Icon(_icon, size: 14, color: color),
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
    );
  }
}
