import 'package:flutter/material.dart';

import '../../../core/services/mqtt_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/status_badge.dart';
import '../../system/models/topology_model.dart';

enum SystemHealth { ok, degraded, unavailable }

class SystemHealthSummary extends StatelessWidget {
  const SystemHealthSummary({
    required this.connectionStatus,
    required this.topology,
    super.key,
  });

  final MqttConnectionStatus connectionStatus;
  final TopologyModel? topology;

  SystemHealth get _health {
    if (connectionStatus != MqttConnectionStatus.connected) {
      return SystemHealth.unavailable;
    }
    final central = topology?.central;
    if (central == null || !central.online) return SystemHealth.unavailable;
    if (topology!.smartNodes.any((node) => !node.online)) {
      return SystemHealth.degraded;
    }
    return SystemHealth.ok;
  }

  @override
  Widget build(BuildContext context) {
    final health = _health;
    final smartNodes = topology?.smartNodes ?? const [];
    final offlineCount = smartNodes.where((node) => !node.online).length;
    final onlineCount = smartNodes.length - offlineCount;

    final (title, message, icon, tone) = switch (health) {
      SystemHealth.ok => (
          'Everything is operating normally',
          smartNodes.isEmpty
              ? 'Central is online. No Smart Nodes are currently registered.'
              : 'Central and all $onlineCount Smart Node${onlineCount == 1 ? '' : 's'} are online.',
          Icons.check_circle_rounded,
          StatusTone.positive,
        ),
      SystemHealth.degraded => (
          '$offlineCount Smart Node${offlineCount == 1 ? '' : 's'} need attention',
          'Core control is available, but some remote loads may be unavailable until those nodes reconnect.',
          Icons.warning_amber_rounded,
          StatusTone.warning,
        ),
      SystemHealth.unavailable => (
          'System connection needs attention',
          connectionStatus == MqttConnectionStatus.connected
              ? 'The broker is connected, but the Central Node is not currently available.'
              : 'The app is not currently receiving live control and telemetry updates.',
          Icons.cloud_off_rounded,
          StatusTone.negative,
        ),
    };

    final accent = switch (health) {
      SystemHealth.ok => AppColors.success,
      SystemHealth.degraded => AppColors.warning,
      SystemHealth.unavailable => AppColors.error,
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
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
                  color: accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.label),
                    const SizedBox(height: 3),
                    Text(message, style: AppTextStyles.caption),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              StatusBadge(
                label: switch (health) {
                  SystemHealth.ok => 'Healthy',
                  SystemHealth.degraded => 'Degraded',
                  SystemHealth.unavailable => 'Offline',
                },
                tone: tone,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              _FactChip(
                icon: Icons.hub_outlined,
                label: connectionStatus == MqttConnectionStatus.connected
                    ? 'MQTT connected'
                    : 'MQTT disconnected',
                positive: connectionStatus == MqttConnectionStatus.connected,
              ),
              _FactChip(
                icon: Icons.memory_outlined,
                label: topology?.central?.online == true
                    ? 'Central online'
                    : 'Central unavailable',
                positive: topology?.central?.online == true,
              ),
              if (smartNodes.isNotEmpty)
                _FactChip(
                  icon: Icons.device_hub_outlined,
                  label: offlineCount == 0
                      ? '$onlineCount/${smartNodes.length} Smart Nodes online'
                      : '$offlineCount offline · $onlineCount online',
                  positive: offlineCount == 0,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FactChip extends StatelessWidget {
  const _FactChip({
    required this.icon,
    required this.label,
    required this.positive,
  });

  final IconData icon;
  final String label;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: positive ? AppColors.success : AppColors.textSecondary,
          ),
          const SizedBox(width: 6),
          Text(label, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}
