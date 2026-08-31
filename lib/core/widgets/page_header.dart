import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// One page-level hierarchy for every workspace surface.
///
/// The title and context stay together while actions collapse underneath on
/// narrow screens. This avoids every feature inventing its own heading row.
class PageHeader extends StatelessWidget {
  const PageHeader({
    required this.title,
    super.key,
    this.subtitle,
    this.eyebrow,
    this.actions = const <Widget>[],
  });

  final String title;
  final String? subtitle;
  final String? eyebrow;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 680;

        final heading = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (eyebrow != null) ...[
              Text(eyebrow!.toUpperCase(), style: AppTextStyles.overline),
              const SizedBox(height: AppSpacing.xxs),
            ],
            Text(title, style: AppTextStyles.pageTitle),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.xs),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Text(subtitle!, style: AppTextStyles.subtitle),
              ),
            ],
          ],
        );

        if (actions.isEmpty) return heading;

        final actionWrap = Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: actions,
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              heading,
              const SizedBox(height: AppSpacing.md),
              actionWrap,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: heading),
            const SizedBox(width: AppSpacing.lg),
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xxs),
              child: actionWrap,
            ),
          ],
        );
      },
    );
  }
}

/// Compact contextual status used next to page-level actions.
class HeaderStatus extends StatelessWidget {
  const HeaderStatus({required this.label, required this.color, super.key});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 36),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: color == AppColors.offline
                  ? AppColors.textSecondary
                  : color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
