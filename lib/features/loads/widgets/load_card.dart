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
    final priority = LoadPriorityLevel.bucketFor(load.priority);
    final deferred = !isOn && load.rejectionReason != null;

    return Material(
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(
          color: deferred
              ? AppColors.warning.withValues(alpha: 0.32)
              : AppColors.border,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        mouseCursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
        hoverColor: AppColors.primary.withValues(alpha: 0.03),
        focusColor: AppColors.primarySoft,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isOn
                          ? AppColors.successSoft
                          : AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Icon(
                      isOn ? Icons.flash_on_rounded : Icons.power_settings_new_rounded,
                      color: isOn ? AppColors.success : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          load.name,
                          style: AppTextStyles.sectionTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          load.owningNodeName ?? load.owningNodeMac,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  StatusBadge(
                    label: !load.available
                        ? 'Unavailable'
                        : isOn
                            ? 'On'
                            : 'Off',
                    tone: !load.available
                        ? StatusTone.negative
                        : isOn
                            ? StatusTone.positive
                            : StatusTone.neutral,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              const Divider(),
              const SizedBox(height: AppSpacing.sm),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _CardMetric(
                      label: 'Mode',
                      value: load.mode == LoadMode.auto ? 'Automatic' : 'Fixed',
                    ),
                  ),
                  Expanded(
                    child: _CardMetric(
                      label: 'Priority',
                      value: '${priority.label} · ${load.priority}/10',
                    ),
                  ),
                  Expanded(
                    child: _CardMetric(
                      label: 'Rated power',
                      value: Formatters.power(load.ratedPowerW),
                    ),
                  ),
                ],
              ),
              if (load.schedule.enabled) ...[
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    const Icon(
                      Icons.schedule_outlined,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        'Preferred window  ${_scheduleLabel(load.schedule)}',
                        style: AppTextStyles.caption,
                      ),
                    ),
                  ],
                ),
              ],
              if (deferred) ...[
                const SizedBox(height: AppSpacing.md),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warningSoft,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: AppColors.warning,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          load.rejectionReason!.friendlyText,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.warning,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Updated ${Formatters.relativeTime(load.lastUpdated)}',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                  if (onTap != null)
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: AppColors.textTertiary,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _scheduleLabel(LoadSchedule schedule) {
    final startHour = schedule.startHour ?? 0;
    final startMinute = schedule.startMinute ?? 0;
    final endHour = schedule.endHour ?? ((startHour + 1) % 24);
    final endMinute = schedule.endMinute ?? startMinute;
    return '${Formatters.timeOfDay(startHour, startMinute)} – ${Formatters.timeOfDay(endHour, endMinute)}';
  }
}

class _CardMetric extends StatelessWidget {
  const _CardMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.caption),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.label,
          ),
        ],
      ),
    );
  }
}
