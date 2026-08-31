import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../loads/models/load_model.dart';

class NodeLoadRow extends StatelessWidget {
  const NodeLoadRow({required this.load, super.key, this.onTap});

  final LoadModel load;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isOn = load.displayState == true;
    final color = !load.available
        ? AppColors.textSecondary
        : isOn
        ? AppColors.success
        : AppColors.textSecondary;

    return Material(
      color: AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 10,
          ),
          child: Row(
            children: [
              Icon(
                isOn
                    ? Icons.flash_on_rounded
                    : Icons.power_settings_new_rounded,
                size: 16,
                color: color,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  load.name,
                  style: AppTextStyles.body,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                Formatters.power(load.ratedPowerW),
                style: AppTextStyles.caption,
              ),
              if (onTap != null) ...[
                const SizedBox(width: 2),
                const Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
