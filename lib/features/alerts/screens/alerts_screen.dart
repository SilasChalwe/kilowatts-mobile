import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/responsive_content.dart';
import '../../../core/widgets/section_card.dart';
import '../models/alert_model.dart';
import '../widgets/alert_card.dart';

enum _AlertFilter { all, unread, critical, warning, info }

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  _AlertFilter _filter = _AlertFilter.all;

  List<AlertModel> _apply(List<AlertModel> alerts) {
    switch (_filter) {
      case _AlertFilter.all:
        return alerts;
      case _AlertFilter.unread:
        return alerts.where((alert) => !alert.acknowledged).toList();
      case _AlertFilter.critical:
        return alerts
            .where((alert) => alert.severity == AlertSeverity.critical)
            .toList();
      case _AlertFilter.warning:
        return alerts
            .where((alert) => alert.severity == AlertSeverity.warning)
            .toList();
      case _AlertFilter.info:
        return alerts
            .where((alert) => alert.severity == AlertSeverity.info)
            .toList();
    }
  }

  Future<void> _openAlert(AlertModel alert) async {
    final appState = AppStateScope.of(context);
    if (!alert.acknowledged) {
      await appState.setAlertRead(alert.id, true);
    }
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(alert.title),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(alert.message, style: AppTextStyles.body),
              const SizedBox(height: AppSpacing.lg),
              SectionRow(
                label: 'Received',
                value: Formatters.relativeTime(alert.timestamp),
              ),
              SectionRow(
                label: 'Severity',
                value: _severityLabel(alert.severity),
              ),
              if (alert.nodeMac != null)
                SectionRow(label: 'Node', value: alert.nodeMac!),
              if (alert.loadId != null)
                SectionRow(label: 'Load', value: alert.loadId!),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAlert(AlertModel alert) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete notification?'),
        content: Text(
          'This will remove “${alert.message.trim().isEmpty ? alert.title : alert.message}” from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await AppStateScope.of(context).deleteAlert(alert.id);
  }

  Future<void> _handleAction(AlertModel alert, AlertCardAction action) async {
    final appState = AppStateScope.of(context);
    switch (action) {
      case AlertCardAction.open:
        await _openAlert(alert);
        return;
      case AlertCardAction.markRead:
        await appState.setAlertRead(alert.id, true);
        return;
      case AlertCardAction.markUnread:
        await appState.setAlertRead(alert.id, false);
        return;
      case AlertCardAction.delete:
        await _deleteAlert(alert);
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);

    return SafeArea(
      child: ValueListenableBuilder<List<AlertModel>>(
        valueListenable: appState.alerts,
        builder: (context, alerts, _) {
          final filtered = _apply(alerts);
          final unread = alerts.where((alert) => !alert.acknowledged).length;

          return ListView(
            children: [
              ResponsiveContent(
                maxWidth: 980,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (alerts.isNotEmpty)
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              unread == 0
                                  ? '${alerts.length} notifications'
                                  : '$unread unread · ${alerts.length} total',
                              style: AppTextStyles.caption,
                            ),
                          ),
                          if (unread > 0)
                            OutlinedButton.icon(
                              onPressed: appState.acknowledgeAllAlerts,
                              icon: const Icon(
                                Icons.done_all_rounded,
                                size: 18,
                              ),
                              label: const Text('Mark all read'),
                            ),
                        ],
                      ),
                    if (alerts.isNotEmpty)
                      const SizedBox(height: AppSpacing.md),
                    if (alerts.isNotEmpty)
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: [
                          for (final filter in _AlertFilter.values)
                            ChoiceChip(
                              label: Text(_label(filter)),
                              selected: _filter == filter,
                              onSelected: (_) =>
                                  setState(() => _filter = filter),
                            ),
                        ],
                      ),
                    if (alerts.isNotEmpty)
                      const SizedBox(height: AppSpacing.md),
                    if (filtered.isEmpty)
                      EmptyState(
                        icon: alerts.isEmpty
                            ? Icons.notifications_none_rounded
                            : Icons.filter_alt_off_outlined,
                        title: alerts.isEmpty
                            ? 'No notifications'
                            : 'Nothing in this view',
                      )
                    else
                      Column(
                        children: [
                          for (
                            var index = 0;
                            index < filtered.length;
                            index++
                          ) ...[
                            AlertCard(
                              alert: filtered[index],
                              onOpen: () => _openAlert(filtered[index]),
                              onAction: (action) =>
                                  _handleAction(filtered[index], action),
                            ),
                            if (index != filtered.length - 1)
                              const SizedBox(height: AppSpacing.xs),
                          ],
                        ],
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _label(_AlertFilter filter) {
    switch (filter) {
      case _AlertFilter.all:
        return 'All';
      case _AlertFilter.unread:
        return 'Unread';
      case _AlertFilter.critical:
        return 'Critical';
      case _AlertFilter.warning:
        return 'Warning';
      case _AlertFilter.info:
        return 'Information';
    }
  }

  String _severityLabel(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.critical:
        return 'Critical';
      case AlertSeverity.warning:
        return 'Warning';
      case AlertSeverity.info:
        return 'Information';
    }
  }
}
