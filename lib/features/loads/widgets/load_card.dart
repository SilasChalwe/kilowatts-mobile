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
    final hasSchedule = load.schedule.enabled;
    final deferred = !isOn && load.rejectionReason != null;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: deferred
                  ? AppColors.warning.withValues(alpha: 0.35)
                  : AppColors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: (isOn ? AppColors.success : AppColors.surfaceMuted)
                          .withValues(alpha: isOn ? 0.10 : 1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isOn ? Icons.flash_on_rounded : Icons.power_settings_new_rounded,
                      color: isOn
                          ? AppColors.success
                          : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(load.name, style: AppTextStyles.label),
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
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  _MetaChip(
                    icon: load.mode == LoadMode.auto
                        ? Icons.auto_awesome_outlined
                        : Icons.touch_app_outlined,
                    label: load.mode == LoadMode.auto ? 'Auto' : 'Fixed',
                  ),
                  _MetaChip(
                    icon: Icons.flag_outlined,
                    label: '${priority.label} priority · ${load.priority}/10',
                  ),
                  _MetaChip(
                    icon: Icons.bolt_outlined,
                    label: '${Formatters.power(load.plannedPowerW)} planned',
                  ),
                  if (hasSchedule)
                    _MetaChip(
                      icon: Icons.schedule_outlined,
                      label: _scheduleLabel(load.schedule),
                    ),
                ],
              ),
              if (deferred) ...[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
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
              const SizedBox(height: AppSpacing.xs),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onTap,
                  icon: const Icon(Icons.tune_rounded, size: 17),
                  label: const Text('View & control'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _scheduleLabel(LoadSchedule schedule) {
    final startHour = schedule.startHour ?? 0;
    final startMinute = schedule.startMinute ?? 0;
    final endHour = schedule.endHour ?? ((startHour + 1) % 24);
    final endMinute = schedule.endMinute ?? startMinute;
    return '${Formatters.timeOfDay(startHour, startMinute)}–${Formatters.timeOfDay(endHour, endMinute)}';
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 5),
          Text(label, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}
