import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/section_card.dart';
import '../../system/models/system_state_model.dart';

class OverviewPowerAllocationCard extends StatelessWidget {
  const OverviewPowerAllocationCard({required this.state, super.key});

  final SystemStateModel state;

  @override
  Widget build(BuildContext context) {
    final budget = state.availablePowerW;
    final automatic = state.autoLoadPowerW;
    final double? utilization =
        budget == null || budget <= 0 || automatic == null
        ? null
        : (automatic / budget).clamp(0.0, 1.0).toDouble();

    return SectionCard(
      title: 'Power allocation',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            Formatters.power(state.estimatedTotalLoadPowerW),
            style: AppTextStyles.display.copyWith(fontSize: 28),
          ),
          const SizedBox(height: 2),
          const Text('Active load power', style: AppTextStyles.caption),
          const SizedBox(height: AppSpacing.md),
          const Divider(),
          SectionRow(
            label: 'Fixed loads ON',
            value: Formatters.power(state.fixedLoadPowerW),
          ),
          SectionRow(
            label: 'Automatic loads ON',
            value: Formatters.power(state.autoLoadPowerW),
          ),
          SectionRow(
            label: 'Automatic budget',
            value: Formatters.power(state.availablePowerW),
          ),
          SectionRow(
            label: 'Budget remaining',
            value: Formatters.power(state.remainingPowerW),
          ),
          if (utilization != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Automatic budget used',
                    style: AppTextStyles.caption,
                  ),
                ),
                Text(
                  '${(utilization * 100).round()}%',
                  style: AppTextStyles.label,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Semantics(
              label:
                  'Automatic power budget ${(utilization * 100).round()} percent used',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: LinearProgressIndicator(
                  value: utilization,
                  minHeight: 7,
                  backgroundColor: AppColors.surfaceMuted,
                  valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          SectionRow(
            label: 'Last optimization',
            value: Formatters.relativeTime(state.lastOptimizationAt),
            muted: state.lastOptimizationAt == null,
          ),
        ],
      ),
    );
  }
}
