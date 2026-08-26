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
    final accent = isLow ? AppColors.warning : AppColors.success;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 144),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            height: 76,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: soc == null ? 0 : (soc / 100).clamp(0, 1),
                    strokeWidth: 7,
                    strokeCap: StrokeCap.round,
                    backgroundColor: AppColors.surfaceMuted,
                    valueColor: AlwaysStoppedAnimation(accent),
                  ),
                ),
                Text(
                  Formatters.percent(soc),
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Battery state of charge',
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${Formatters.voltage(state.batteryVoltage)}  ·  ${Formatters.current(state.batteryCurrent)}',
                  style: AppTextStyles.sectionTitle,
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        isLow ? 'Battery reserve is low' : 'Battery reserve is healthy',
                        style: AppTextStyles.caption.copyWith(color: accent),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
