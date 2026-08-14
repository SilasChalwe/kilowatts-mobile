import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/utils/validators.dart';
import '../../system/models/node_model.dart';
import '../models/setup_session.dart';
import '../widgets/node_configuration_card.dart';

class NodeConfigurationScreen extends StatefulWidget {
  const NodeConfigurationScreen({
    required this.node,
    required this.setupSession,
    super.key,
  });

  final NodeModel node;
  final SetupSession setupSession;

  @override
  State<NodeConfigurationScreen> createState() =>
      _NodeConfigurationScreenState();
}

class _NodeConfigurationScreenState extends State<NodeConfigurationScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text:
        widget.setupSession.nodeNames[widget.node.mac] ??
        widget.node.displayName,
  );
  late final _locationController = TextEditingController(
    text: widget.setupSession.nodeLocations[widget.node.mac] ?? '',
  );

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    widget.setupSession.nodeNames[widget.node.mac] = name;
    widget.setupSession.nodeLocations[widget.node.mac] = _locationController
        .text
        .trim();
    AppStateScope.of(context).setNodeNameOverride(widget.node.mac, name);

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Node Configuration')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              AppTextField(
                label: 'Node Name',
                controller: _nameController,
                hintText: 'e.g. Sitting Room',
                validator: (value) =>
                    Validators.requiredField(value, fieldName: 'Node name'),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Location / Room (optional)',
                controller: _locationController,
                hintText: 'e.g. Garage',
              ),
              const SizedBox(height: AppSpacing.lg),
              NodeConfigurationCard(node: widget.node),
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(label: 'Save', onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}
