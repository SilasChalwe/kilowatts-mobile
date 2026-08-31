import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/section_card.dart';
import '../../system/models/system_state_model.dart';

class BatteryReserveCard extends StatefulWidget {
  const BatteryReserveCard({required this.state, super.key});

  final SystemStateModel state;

  @override
  State<BatteryReserveCard> createState() => _BatteryReserveCardState();
}

class _BatteryReserveCardState extends State<BatteryReserveCard> {
  double? _draftPercent;

  /// The live reserve value at the moment a change was sent. Central's ack
  /// confirms the command was applied, but its *next* state broadcast is a
  /// separate, later MQTT message — trusting the ack alone and clearing
  /// [_draftPercent] immediately made the slider flash back to this stale
  /// value for the gap in between. Keeping the draft visible until the live
  /// value actually moves away from this baseline avoids that flash.
  double? _baselineBeforeApply;
  bool _isSending = false;
  String? _message;
  bool _messageIsError = false;

  @override
  void didUpdateWidget(covariant BatteryReserveCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_baselineBeforeApply != null &&
        widget.state.reserveSoCPercent != _baselineBeforeApply) {
      // Central has published a fresh value since we applied — it's now
      // safe to trust live state again instead of the optimistic draft.
      setState(() {
        _draftPercent = null;
        _baselineBeforeApply = null;
      });
    }
  }

  Future<void> _apply(double percent) async {
    _baselineBeforeApply = widget.state.reserveSoCPercent;
    setState(() {
      _isSending = true;
      _message = null;
      _draftPercent = percent;
    });
    final outcome = await AppStateScope.of(context).setBatteryReserve(percent);
    if (!mounted) return;
    setState(() {
      _isSending = false;
      _messageIsError = !outcome.isConfirmed;
      _message = outcome.isConfirmed
          ? 'Central confirmed the new reserve.'
          : outcome.message ?? 'Central rejected this command.';
      if (!outcome.isConfirmed) {
        // The change didn't take effect — drop the draft immediately so the
        // slider reflects the real, unchanged live value.
        _draftPercent = null;
        _baselineBeforeApply = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final configured = state.reserveConfigured == true;
    final livePercent = state.reserveSoCPercent;
    final sliderValue = (_draftPercent ?? livePercent ?? 20)
        .clamp(0, 100)
        .toDouble();
    final ratedKwh = state.batteryRatedEnergyWattHours == null
        ? null
        : state.batteryRatedEnergyWattHours! / 1000;
    final storedKwh = state.storedEnergyWattHours == null
        ? null
        : state.storedEnergyWattHours! / 1000;
    final usableKwh = state.usableEnergyWattHours == null
        ? null
        : state.usableEnergyWattHours! / 1000;

    return SectionCard(
      title: 'Battery reserve',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (state.batteryCapacityAmpHours != null) ...[
            SectionRow(
              label: 'Battery capacity',
              value:
                  '${state.batteryCapacityAmpHours!.toStringAsFixed(state.batteryCapacityAmpHours! % 1 == 0 ? 0 : 1)} Ah',
            ),
            if (ratedKwh != null)
              SectionRow(
                label: 'Total energy',
                value: Formatters.energy(ratedKwh),
              ),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (!configured)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text('Not configured yet', style: AppTextStyles.label),
            )
          else ...[
            Text(
              '${sliderValue.round()}%',
              style: AppTextStyles.display.copyWith(fontSize: 28),
            ),
            Slider(
              value: sliderValue,
              min: 0,
              max: 100,
              divisions: 100,
              label: '${sliderValue.round()}%',
              onChanged: _isSending
                  ? null
                  : (value) => setState(() => _draftPercent = value),
              onChangeEnd: _isSending ? null : _apply,
            ),
            const Divider(),
            SectionRow(
              label: 'Stored energy',
              value: Formatters.energy(storedKwh),
            ),
            SectionRow(
              label: 'Usable above reserve',
              value: Formatters.energy(usableKwh),
            ),
            if (state.requiredRuntimeConfigured == true)
              SectionRow(
                label: 'Sustainable power',
                value: Formatters.power(state.sustainablePowerW),
              ),
          ],
          if (_message != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: _messageIsError
                    ? AppColors.errorSoft
                    : AppColors.successSoft,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                _message!,
                style: AppTextStyles.caption.copyWith(
                  color: _messageIsError ? AppColors.error : AppColors.success,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
