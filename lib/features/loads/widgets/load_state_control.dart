import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../../core/services/command_outcome.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/primary_button.dart';
import '../models/load_model.dart';

/// FIXED: the user's requested state is authoritative (subject to safety),
/// so this shows a real control. AUTO: Best-First planning decides the
/// target — this only explains what's happening, it never offers a manual
/// override button that would bypass planning.
class LoadStateControl extends StatefulWidget {
  const LoadStateControl({required this.load, super.key});

  final LoadModel load;

  @override
  State<LoadStateControl> createState() => _LoadStateControlState();
}

class _LoadStateControlState extends State<LoadStateControl> {
  bool _isSending = false;
  String? _error;

  Future<void> _setState(bool requestedOn) async {
    setState(() {
      _isSending = true;
      _error = null;
    });

    final outcome = await AppStateScope.of(context).setLoadFixedState(
      nodeMac: widget.load.owningNodeMac,
      relayPin: widget.load.relayPin,
      on: requestedOn,
    );

    if (!mounted) return;
    setState(() {
      _isSending = false;
      _error = outcome.status == CommandStatus.failed ? outcome.message : null;
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
          Row(
            children: [
              Expanded(
                child: Text(
                  'Requested: ${load.requestedState == null ? '—' : (load.requestedState! ? 'ON' : 'OFF')}',
                  style: AppTextStyles.caption,
                ),
              ),
              Expanded(
                child: Text(
                  'Confirmed: ${load.confirmedState == null ? '—' : (load.confirmedState! ? 'ON' : 'OFF')}',
                  style: AppTextStyles.caption,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          PrimaryButton(
            label: _isSending ? 'Sending…' : (isOn ? 'Turn Off' : 'Turn On'),
            isLoading: _isSending,
            onPressed: load.available ? () => _setState(!isOn) : null,
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              _error!,
              style: AppTextStyles.caption.copyWith(color: AppColors.error),
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
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            isOn ? Icons.check_circle_outline : Icons.pause_circle_outline,
            color: isOn ? AppColors.success : AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Automatic mode · Current state: ${isOn ? 'ON' : 'OFF'}',
                  style: AppTextStyles.label,
                ),
                if (!isOn && load.rejectionReason != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Reason: ${load.rejectionReason!.friendlyText}',
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
