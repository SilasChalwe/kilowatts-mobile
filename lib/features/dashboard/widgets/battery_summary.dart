import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../system/models/system_state_model.dart';

class BatterySummary extends StatelessWidget {
  const BatterySummary({required this.state, super.key});

  final SystemStateModel state;

  @override
  Widget build(BuildContext context) {
    final soc = state.batterySocPercent;
    final isLow =
        soc != null && soc <= AppConstants.defaultLowBatteryWarningPercent;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: soc == null ? 0 : (soc / 100).clamp(0, 1),
                  strokeWidth: 6,
                  backgroundColor: AppColors.surfaceMuted,
                  valueColor: AlwaysStoppedAnimation(
                    isLow ? AppColors.warning : AppColors.success,
                  ),
                ),
                Text(
                  Formatters.percent(soc),
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Battery State of Charge',
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: 2),
                Text(
                  '${Formatters.voltage(state.batteryVoltage)} · ${Formatters.current(state.batteryCurrent)}',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (isLow) ...[
                  const SizedBox(height: 2),
                  const Text(
                    'Battery reserve is low',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.warning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
