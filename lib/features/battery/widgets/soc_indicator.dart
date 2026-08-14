import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../system/models/system_state_model.dart';
import 'battery_metric.dart';

class SocIndicator extends StatelessWidget {
  const SocIndicator({required this.state, super.key});

  final SystemStateModel state;

  @override
  Widget build(BuildContext context) {
    final soc = state.batterySocPercent;
    final isLow =
        soc != null && soc <= AppConstants.defaultLowBatteryWarningPercent;
    final isCritical =
        soc != null && soc <= AppConstants.defaultLowBatteryCutoffPercent;

    final color = isCritical
        ? AppColors.error
        : (isLow ? AppColors.warning : AppColors.success);

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
            width: 96,
            height: 96,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: soc == null ? 0 : (soc / 100).clamp(0, 1),
                  strokeWidth: 9,
                  backgroundColor: AppColors.surfaceMuted,
                  valueColor: AlwaysStoppedAnimation(color),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(Formatters.percent(soc), style: AppTextStyles.title),
                    const Text('SoC', style: AppTextStyles.caption),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.sm,
              children: [
                BatteryMetric(
                  label: 'Battery Voltage',
                  value: Formatters.voltage(state.batteryVoltage),
                ),
                BatteryMetric(
                  label: 'Battery Current',
                  value: Formatters.current(state.batteryCurrent),
                ),
                BatteryMetric(
                  label: 'Battery Power',
                  value: Formatters.power(state.batteryPowerW),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
