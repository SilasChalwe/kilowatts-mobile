import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/status_badge.dart';
import '../models/node_model.dart';

class NodeCard extends StatelessWidget {
  const NodeCard({required this.node, super.key, this.onTap});

  final NodeModel node;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isCentral = node.role == NodeRole.central;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Icon(
                isCentral ? Icons.developer_board : Icons.memory_outlined,
                size: 20,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(node.displayName, style: AppTextStyles.label),
                    if (!isCentral)
                      Text(
                        '${Formatters.hopCount(node.hopCount)} · ${node.loads.length} loads',
                        style: AppTextStyles.caption,
                      ),
                  ],
                ),
              ),
              StatusBadge.online(online: node.online),
              if (onTap != null) ...[
                const SizedBox(width: AppSpacing.xxs),
                const Icon(
                  Icons.chevron_right,
                  size: 18,
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
