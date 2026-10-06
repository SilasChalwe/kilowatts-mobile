import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/section_card.dart';
import '../../system/models/system_state_model.dart';
import 'power_plan_dialog.dart';

/// Shows the current power plan as a read-only summary; editing happens in
/// a modal (`showPowerPlanDialog`) reached via the trailing "⋮" button, so
/// the card itself never carries input fields. Firmware's `battery set`
/// command requires `budget`, `reserve` and `minSoc` together every time —
/// there is no partial/reserve-only update
/// (`MqttManager::handleBatteryCommandMessage` rejects the command if any of
/// the three is missing) — but the dialog pre-fills all of them from the
/// current values, so changing just the runtime (independently of
/// budget/reserve, as the frontend contract allows) never requires
/// re-entering the others. `minSoc`/`runtime` are not published back in
/// `state.system`, so this card remembers the last values it successfully
/// applied.
class BatteryReserveCard extends StatefulWidget {
  const BatteryReserveCard({required this.state, this.isLive = true, super.key});

  final SystemStateModel state;

  /// Whether [state] is a live broadcast from a currently-connected Central
  /// node, as opposed to the last value cached locally from a previous
  /// session (`LocalStateService.readCachedSystemState`, restored on app
  /// startup before any connection exists). When false, every reading below
  /// is shown as unavailable and the editor is disabled — otherwise a stale
  /// cached number looks identical to a live one.
  final bool isLive;

  @override
  State<BatteryReserveCard> createState() => _BatteryReserveCardState();
}

class _BatteryReserveCardState extends State<BatteryReserveCard> {
  double? _lastKnownMinSoc = 20;
  double? _lastKnownRuntime;

  Future<void> _openEditor() async {
    final state = widget.state;
    _lastKnownRuntime ??= state.requiredRuntimeHours;
    await showPowerPlanDialog(
      context,
      initialBudget: state.powerBudgetWatts,
      initialReserve: state.powerReserveWatts,
      initialMinSoc: _lastKnownMinSoc,
      initialRuntime: _lastKnownRuntime,
      onApply: ({required budget, required reserve, required minSoc, runtime}) async {
        final outcome = await AppStateScope.of(context).setBatteryPlan(
          budget: budget,
          reserve: reserve,
          minSoc: minSoc,
          runtime: runtime,
        );
        if (outcome.isConfirmed && mounted) {
          setState(() {
            _lastKnownMinSoc = minSoc;
            _lastKnownRuntime = runtime;
          });
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Central confirmed the new power plan.')));
        }
        return outcome;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final isLive = widget.isLive;
    final capacityAh = isLive ? state.batteryCapacityAmpHours : null;
    final nominalVoltage = isLive ? state.batteryNominalVoltageV : null;
    final ratedKwh = !isLive || state.batteryRatedEnergyWattHours == null
        ? null
        : state.batteryRatedEnergyWattHours! / 1000;
    final storedKwh = !isLive || state.storedEnergyWattHours == null
        ? null
        : state.storedEnergyWattHours! / 1000;
    final usableKwh = !isLive || state.usableEnergyWattHours == null
        ? null
        : state.usableEnergyWattHours! / 1000;
    final runtimeAchievable = isLive ? state.requiredRuntimeAchievable : null;

    return SectionCard(
      title: 'Power plan',
      trailing: IconButton(
        icon: const Icon(Icons.more_vert),
        tooltip: 'Edit power plan',
        onPressed: isLive ? _openEditor : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isLive)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.errorSoft,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                'Not connected to Central — readings below are unavailable.',
                style: AppTextStyles.caption.copyWith(color: AppColors.error),
              ),
            ),
          if (capacityAh != null) ...[
            SectionRow(
              label: 'Battery capacity',
              value: '${capacityAh.toStringAsFixed(capacityAh % 1 == 0 ? 0 : 1)} Ah',
            ),
            if (nominalVoltage != null)
              SectionRow(label: 'Nominal voltage', value: Formatters.voltage(nominalVoltage)),
            if (ratedKwh != null)
              SectionRow(label: 'Total energy', value: Formatters.energy(ratedKwh)),
            const SizedBox(height: AppSpacing.sm),
          ],
          SectionRow(label: 'Stored energy', value: Formatters.energy(storedKwh)),
          SectionRow(label: 'Usable above minimum', value: Formatters.energy(usableKwh)),
          if (runtimeAchievable != null)
            SectionRow(
              label: 'Runtime target',
              value: runtimeAchievable ? 'Achievable' : 'Not achievable',
            ),
        ],
      ),
    );
  }
}
