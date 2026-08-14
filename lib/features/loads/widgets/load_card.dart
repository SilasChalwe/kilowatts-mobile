import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/status_badge.dart';
import '../models/load_model.dart';

class LoadCard extends StatelessWidget {
  const LoadCard({required this.load, super.key, this.onTap});

  final LoadModel load;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isOn = load.displayState == true;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Icon(
                isOn ? Icons.flash_on_rounded : Icons.flash_off_outlined,
                color: isOn ? AppColors.success : AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(load.name, style: AppTextStyles.label),
                    const SizedBox(height: 2),
                    Text(
                      '${load.owningNodeName ?? load.owningNodeMac} · ${Formatters.power(load.plannedPowerW)} planned',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StatusBadge(
                    label: load.mode == LoadMode.fixed ? 'Fixed' : 'Auto',
                    tone: StatusTone.neutral,
                    showDot: false,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  if (!load.available)
                    const StatusBadge(
                      label: 'Unavailable',
                      tone: StatusTone.negative,
                    )
                  else
                    StatusBadge(
                      label: isOn ? 'On' : 'Off',
                      tone: isOn ? StatusTone.positive : StatusTone.neutral,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
