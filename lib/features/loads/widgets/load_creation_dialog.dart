import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../system/models/system_node_model.dart';
import '../models/load_configuration.dart';
import '../models/load_model.dart';

Future<LoadConfiguration?> showLoadCreationDialog(
  BuildContext context, {
  required List<SystemNodeModel> nodes,
  required List<LoadModel> existingLoads,
}) => showDialog<LoadConfiguration>(
  context: context,
  builder: (_) =>
      _LoadCreationDialog(nodes: nodes, existingLoads: existingLoads),
);

class _LoadCreationDialog extends StatefulWidget {
  const _LoadCreationDialog({required this.nodes, required this.existingLoads});

  final List<SystemNodeModel> nodes;
  final List<LoadModel> existingLoads;

  @override
  State<_LoadCreationDialog> createState() => _LoadCreationDialogState();
}

class _LoadCreationDialogState extends State<_LoadCreationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _power = TextEditingController();
  late SystemNodeModel _node;
  late int _pin;
  bool _activeHigh = false;
  LoadPowerType _powerType = LoadPowerType.dc;
  LoadMode _mode = LoadMode.auto;
  int _priority = 5;

  List<int> _freePins(SystemNodeModel node) {
    final used = widget.existingLoads
        .where((load) => load.owningNodeMac == node.mac)
        .map((load) => load.relayPin)
        .toSet();
    return node.availableRelayPins
        .where((pin) => !used.contains(pin))
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _node = widget.nodes.first;
    _pin = _freePins(_node).first;
  }

  @override
  void dispose() {
    _name.dispose();
    _power.dispose();
    super.dispose();
  }

  void _changeNode(SystemNodeModel node) {
    setState(() {
      _node = node;
      _pin = _freePins(node).first;
    });
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      LoadConfiguration(
        nodeMac: _node.mac,
        name: _name.text.trim(),
        relayPin: _pin,
        relayActiveHigh: _activeHigh,
        powerRatingWatts: double.parse(_power.text.trim()),
        priority: _priority,
        mode: _mode,
        powerType: _powerType,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final freePins = _freePins(_node);
    return AlertDialog(
      title: const Text('Add load'),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<SystemNodeModel>(
                  initialValue: _node,
                  decoration: const InputDecoration(labelText: 'Smart node'),
                  items: [
                    for (final node in widget.nodes)
                      DropdownMenuItem(
                        value: node,
                        child: Text(node.displayName),
                      ),
                  ],
                  onChanged: (value) => _changeNode(value!),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Load name'),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    return text.isEmpty || text.length >= 16
                        ? 'Use 1–15 characters.'
                        : null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<int>(
                  key: ValueKey(_node.mac),
                  initialValue: _pin,
                  decoration: const InputDecoration(labelText: 'Relay channel'),
                  items: [
                    for (final pin in freePins)
                      DropdownMenuItem(value: pin, child: Text('GPIO $pin')),
                  ],
                  onChanged: (value) => setState(() => _pin = value!),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active-high relay'),
                  value: _activeHigh,
                  onChanged: (value) => setState(() => _activeHigh = value),
                ),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<LoadPowerType>(
                        initialValue: _powerType,
                        decoration: const InputDecoration(
                          labelText: 'Power type',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: LoadPowerType.dc,
                            child: Text('DC'),
                          ),
                          DropdownMenuItem(
                            value: LoadPowerType.ac,
                            child: Text('AC'),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => _powerType = value!),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: TextFormField(
                        controller: _power,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Rated power',
                          suffixText: 'W',
                        ),
                        validator: (value) {
                          final watts = double.tryParse(value?.trim() ?? '');
                          return watts == null || watts < 0
                              ? 'Enter watts ≥ 0.'
                              : null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<LoadMode>(
                  initialValue: _mode,
                  decoration: const InputDecoration(labelText: 'Initial mode'),
                  items: const [
                    DropdownMenuItem(value: LoadMode.auto, child: Text('Auto')),
                    DropdownMenuItem(
                      value: LoadMode.fixed,
                      child: Text('Fixed'),
                    ),
                  ],
                  onChanged: (value) => setState(() => _mode = value!),
                ),
                const SizedBox(height: AppSpacing.md),
                Text('Priority $_priority/10', style: AppTextStyles.label),
                Slider(
                  value: _priority.toDouble(),
                  min: 0,
                  max: 10,
                  divisions: 10,
                  label: '$_priority',
                  onChanged: (value) =>
                      setState(() => _priority = value.round()),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Add load')),
      ],
    );
  }
}
