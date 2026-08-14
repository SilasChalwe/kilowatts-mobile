import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

class SetupProgressIndicator extends StatelessWidget {
  const SetupProgressIndicator({
    required this.step,
    required this.title,
    super.key,
  });

  final int step;
  final String title;

  @override
  Widget build(BuildContext context) {
    final progress = step / AppConstants.setupTotalSteps;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Step $step of ${AppConstants.setupTotalSteps}',
          style: AppTextStyles.caption,
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(title, style: AppTextStyles.title),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress.clamp(0, 1),
            minHeight: 6,
            backgroundColor: AppColors.surfaceMuted,
            valueColor: const AlwaysStoppedAnimation(AppColors.primary),
          ),
        ),
      ],
    );
  }
}
