import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../models/branch_model.dart';

class BranchCard extends StatelessWidget {
  const BranchCard({
    required this.branch,
    super.key,
    this.loadName,
    this.onTap,
  });

  final BranchModel branch;
  final String? loadName;
  final VoidCallback? onTap;

  Color get _statusColor {
    switch (branch.status) {
      case BranchStatus.healthy:
        return AppColors.success;
      case BranchStatus.warning:
        return AppColors.warning;
      case BranchStatus.fault:
        return AppColors.error;
      case BranchStatus.unknown:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
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
                Icons.electrical_services_outlined,
                size: 16,
                color: _statusColor,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  loadName ?? branch.name ?? 'Relay ${branch.relayPin}',
                  style: AppTextStyles.body,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                Formatters.current(branch.currentDrawA),
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
