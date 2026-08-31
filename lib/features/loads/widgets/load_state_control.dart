import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../../core/services/command_outcome.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/primary_button.dart';
import '../models/load_model.dart';

/// FIXED loads expose a direct requested ON/OFF action. AUTO loads remain
/// controlled by Best-First Search and instead explain their current result.
class LoadStateControl extends StatefulWidget {
  const LoadStateControl({required this.load, super.key});

  final LoadModel load;

  @override
  State<LoadStateControl> createState() => _LoadStateControlState();
}

class _LoadStateControlState extends State<LoadStateControl> {
  bool _isSending = false;
  String? _message;
  bool _messageIsError = false;

  Future<void> _setState(bool requestedOn) async {
    setState(() {
      _isSending = true;
      _message = requestedOn
          ? 'Sending ON request to Central…'
          : 'Sending OFF request to Central…';
      _messageIsError = false;
    });

    final outcome = await AppStateScope.of(context).setLoadFixedState(
      nodeMac: widget.load.owningNodeMac,
      relayPin: widget.load.relayPin,
      on: requestedOn,
    );

    if (!mounted) return;
    setState(() {
      _isSending = false;
      _messageIsError = outcome.status == CommandStatus.failed;
      _message = outcome.status == CommandStatus.confirmed
          ? 'Central confirmed the ${requestedOn ? 'ON' : 'OFF'} request.'
          : outcome.message ?? 'Central rejected this command.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final load = widget.load;

    if (load.mode == LoadMode.fixed) {
      final isOn = load.displayState == true;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  isOn ? Icons.power_rounded : Icons.power_off_rounded,
                  color: isOn ? AppColors.success : AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isOn ? 'Requested ON' : 'Requested OFF',
                        style: AppTextStyles.label,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          PrimaryButton(
            label: _isSending
                ? 'Waiting for Central…'
                : (isOn ? 'Turn Off' : 'Turn On'),
            isLoading: _isSending,
            onPressed: load.available && !_isSending
                ? () => _setState(!isOn)
                : null,
          ),
          if (_message != null) ...[
            const SizedBox(height: AppSpacing.xs),
            _CommandMessage(
              message: _message!,
              isError: _messageIsError,
              isPending: _isSending,
            ),
          ],
        ],
      );
    }

    final isOn = load.displayState == true;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isOn ? Icons.auto_awesome_rounded : Icons.pause_circle_outline,
            color: isOn ? AppColors.success : AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Automatic · ${isOn ? 'Selected by Best-First Search' : 'Currently deferred'}',
                  style: AppTextStyles.label,
                ),
                if (!isOn && load.rejectionReason != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    load.rejectionReason!.friendlyText,
                    style: AppTextStyles.caption,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommandMessage extends StatelessWidget {
  const _CommandMessage({
    required this.message,
    required this.isError,
    required this.isPending,
  });

  final String message;
  final bool isError;
  final bool isPending;

  @override
  Widget build(BuildContext context) {
    final color = isError
        ? AppColors.error
        : isPending
        ? AppColors.info
        : AppColors.success;
    final icon = isError
        ? Icons.error_outline_rounded
        : isPending
        ? Icons.sync_rounded
        : Icons.check_circle_outline_rounded;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.caption.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
