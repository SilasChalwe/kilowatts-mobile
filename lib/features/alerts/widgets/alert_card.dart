import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../models/alert_model.dart';

enum AlertCardAction { open, markRead, markUnread, delete }

class AlertCard extends StatelessWidget {
  const AlertCard({
    required this.alert,
    super.key,
    this.compact = false,
    this.onOpen,
    this.onAction,
  });

  final AlertModel alert;
  final bool compact;
  final VoidCallback? onOpen;
  final ValueChanged<AlertCardAction>? onAction;

  (IconData, Color) get _severityStyle {
    switch (alert.severity) {
      case AlertSeverity.critical:
        return (Icons.error_outline_rounded, AppColors.error);
      case AlertSeverity.warning:
        return (Icons.warning_amber_rounded, AppColors.warning);
      case AlertSeverity.info:
        return (Icons.notifications_none_rounded, AppColors.info);
    }
  }

  String get _primaryMessage {
    final message = alert.message.trim();
    return message.isEmpty ? alert.title : message;
  }

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _severityStyle;
    final unread = !alert.acknowledged;

    return Material(
      color: unread
          ? AppColors.primarySoft.withValues(alpha: 0.42)
          : AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: compact ? 10 : AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: unread
                  ? AppColors.primary.withValues(alpha: 0.18)
                  : AppColors.border,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            _primaryMessage,
                            maxLines: compact ? 1 : 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.body.copyWith(
                              fontWeight: unread
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                        if (unread) ...[
                          const SizedBox(width: 8),
                          Semantics(
                            label: 'Unread notification',
                            child: Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(top: 6),
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (!compact &&
                        alert.title.trim().isNotEmpty &&
                        alert.title.trim() != _primaryMessage) ...[
                      const SizedBox(height: 3),
                      Text(
                        alert.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          Formatters.relativeTime(alert.timestamp),
                          style: AppTextStyles.caption,
                        ),
                        if (!compact && unread) ...[
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            'Unread',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (!compact && onAction != null) ...[
                const SizedBox(width: AppSpacing.xs),
                PopupMenuButton<AlertCardAction>(
                  tooltip: 'Notification actions',
                  onSelected: onAction,
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: AlertCardAction.open,
                      child: _MenuItem(
                        icon: Icons.open_in_new_rounded,
                        label: 'Open',
                      ),
                    ),
                    PopupMenuItem(
                      value: unread
                          ? AlertCardAction.markRead
                          : AlertCardAction.markUnread,
                      child: _MenuItem(
                        icon: unread
                            ? Icons.mark_email_read_outlined
                            : Icons.mark_email_unread_outlined,
                        label: unread ? 'Mark as read' : 'Mark as unread',
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: AlertCardAction.delete,
                      child: _MenuItem(
                        icon: Icons.delete_outline_rounded,
                        label: 'Delete',
                        destructive: true,
                      ),
                    ),
                  ],
                  icon: const Icon(Icons.more_horiz_rounded),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.error : null;
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: AppSpacing.sm),
        Text(label, style: color == null ? null : TextStyle(color: color)),
      ],
    );
  }
}
