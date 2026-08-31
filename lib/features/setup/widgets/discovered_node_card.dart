import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/status_badge.dart';
import '../../system/models/node_model.dart';

class DiscoveredNodeCard extends StatelessWidget {
  const DiscoveredNodeCard({
    required this.node,
    required this.loadCount,
    super.key,
    this.isConfigured = false,
    this.onTap,
  });

  final NodeModel node;
  final int loadCount;
  final bool isConfigured;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final needsConfiguration = node.isNewlyDiscovered && !isConfigured;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: needsConfiguration ? AppColors.primary : AppColors.border,
          width: needsConfiguration ? 1.4 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            node.displayName,
                            style: AppTextStyles.label,
                          ),
                        ),
                        StatusBadge.online(online: node.online),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      needsConfiguration
                          ? 'New Node · $loadCount ${loadCount == 1 ? 'load' : 'loads'} detected'
                          : '${node.role.name == 'central' ? 'Central Node' : 'Smart Node'} · $loadCount ${loadCount == 1 ? 'load' : 'loads'}',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: AppSpacing.xs),
                Text(
                  needsConfiguration ? 'Configure' : 'Edit',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: AppColors.primary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
