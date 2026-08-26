import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/section_card.dart';
import '../models/setup_session.dart';
import '../widgets/safety_parameter_field.dart';
import '../widgets/setup_progress_indicator.dart';
import 'branch_load_configuration_screen.dart';

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
      appBar: AppBar(title: const Text('Safety thresholds')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              const SetupProgressIndicator(step: 3, title: 'Safety Thresholds'),
              const SizedBox(height: AppSpacing.lg),
              SectionCard(
                title: 'Battery policy',
                child: Column(
                  children: [
                    SafetyParameterField(
                      label: 'Minimum state of charge',
                      description: 'Auto-load cutoff level',
                      unit: '%',
                      initialValue: draft.lowBatteryCutoffPercent,
                      onChanged: (v) => draft.lowBatteryCutoffPercent = v,
                    ),
                    SafetyParameterField(
                      label: 'Required runtime',
                      description: 'Battery runtime target',
                      unit: 'h',
                      initialValue: draft.targetRuntimeHours,
                      onChanged: (v) => draft.targetRuntimeHours = v,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SectionCard(
                title: 'Current limits',
                child: Column(
                  children: [
                    SafetyParameterField(
                      label: 'Maximum battery discharge',
                      description: 'Battery current limit',
                      unit: 'A',
                      initialValue: draft.maxBatteryDischargeCurrentA,
                      onChanged: (v) => draft.maxBatteryDischargeCurrentA = v,
                    ),
                    SafetyParameterField(
                      label: 'Maximum main current',
                      description: 'Main distribution limit',
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
