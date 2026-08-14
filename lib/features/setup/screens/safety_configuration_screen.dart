import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/section_card.dart';
import '../models/setup_session.dart';
import '../widgets/safety_parameter_field.dart';
import '../widgets/setup_progress_indicator.dart';
import 'branch_load_configuration_screen.dart';

/// Firmware does not yet publish a `config/system` topic, so there is no
/// live "physical maximum" ceiling to show here — this screen only ever
/// captures the user's draft, which is submitted (and honestly rejected
/// today, see `MqttService.sendSafetyConfig`) at Setup Summary.
class SafetyConfigurationScreen extends StatefulWidget {
  const SafetyConfigurationScreen({required this.setupSession, super.key});

  final SetupSession setupSession;

  @override
  State<SafetyConfigurationScreen> createState() =>
      _SafetyConfigurationScreenState();
}

class _SafetyConfigurationScreenState extends State<SafetyConfigurationScreen> {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final draft = widget.setupSession.safety;

    return Scaffold(
      appBar: AppBar(title: const Text('Safety Thresholds')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              const SetupProgressIndicator(step: 3, title: 'Safety Thresholds'),
              const SizedBox(height: AppSpacing.lg),
              SectionCard(
                title: 'Battery Protection',
                child: Column(
                  children: [
                    SafetyParameterField(
                      label: 'Low Battery Cutoff',
                      description:
                          'Minimum battery % before Auto loads are shed',
                      unit: '%',
                      initialValue: draft.lowBatteryCutoffPercent,
                      onChanged: (v) => draft.lowBatteryCutoffPercent = v,
                    ),
                    SafetyParameterField(
                      label: 'Low Battery Warning',
                      description: 'Battery % that raises a warning alert',
                      unit: '%',
                      initialValue: draft.lowBatteryWarningPercent,
                      onChanged: (v) => draft.lowBatteryWarningPercent = v,
                    ),
                    SafetyParameterField(
                      label: 'Target Runtime',
                      description: 'Hours of reserve the system aims to keep',
                      unit: 'h',
                      initialValue: draft.targetRuntimeHours,
                      onChanged: (v) => draft.targetRuntimeHours = v,
                    ),
                    SafetyParameterField(
                      label: 'Safety Margin',
                      description: 'Extra headroom kept in reserve',
                      unit: '%',
                      initialValue: draft.safetyMarginPercent,
                      onChanged: (v) => draft.safetyMarginPercent = v,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SectionCard(
                title: 'Current Limits',
                child: Column(
                  children: [
                    SafetyParameterField(
                      label: 'Max Battery Discharge Current',
                      description: 'Battery-side operating limit',
                      unit: 'A',
                      initialValue: draft.maxBatteryDischargeCurrentA,
                      onChanged: (v) => draft.maxBatteryDischargeCurrentA = v,
                    ),
                    SafetyParameterField(
                      label: 'Main Current Limit',
                      description: 'System-wide operating limit',
                      unit: 'A',
                      initialValue: draft.mainCurrentLimitA,
                      onChanged: (v) => draft.mainCurrentLimitA = v,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                label: 'Continue',
                onPressed: () {
                  if (!_formKey.currentState!.validate()) return;
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => BranchLoadConfigurationScreen(
                        setupSession: widget.setupSession,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
