import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../../core/services/command_outcome.dart';
import '../../../core/services/mqtt_config.dart';
import '../../../core/services/mqtt_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/responsive_content.dart';
import '../../../core/widgets/section_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../../loads/models/load_model.dart';
import '../../loads/widgets/load_configuration_dialog.dart';
import '../models/installer_node_model.dart';
import 'installer_configuration_dialogs.dart';

class InstallerConsoleScreen extends StatefulWidget {
  const InstallerConsoleScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<InstallerConsoleScreen> createState() => _InstallerConsoleScreenState();
}

class _InstallerConsoleScreenState extends State<InstallerConsoleScreen> {
  MqttConfig? _config;
  Map<String, dynamic>? _lastSafety;
  Map<String, dynamic>? _lastBattery;
  bool _loading = true;
  bool _sourceBusy = false;
  bool _initialized = false;
  final Set<String> _loadsBeingUpdated = <String>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _loadSummaries();
  }

  Future<void> _loadSummaries() async {
    final appState = AppStateScope.of(context);
    final values = await Future.wait<dynamic>([
      appState.loadMqttConfig(),
      appState.readLastInstallerSafetyConfig(),
      appState.readLastInstallerBatteryConfig(),
    ]);
    if (!mounted) return;
    setState(() {
      _config = values[0] as MqttConfig;
      _lastSafety = values[1] as Map<String, dynamic>?;
      _lastBattery = values[2] as Map<String, dynamic>?;
      _loading = false;
    });
  }

  void _message(String text, {bool error = false}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                error
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(child: Text(text)),
            ],
          ),
          backgroundColor: error ? AppColors.error : AppColors.textPrimary,
        ),
      );
  }

  Future<void> _editBroker() async {
    final initial = _config ?? const MqttConfig.unconfigured();
    final updated = await showInstallerBrokerDialog(context, initial);
    if (updated == null || !mounted) return;

    final appState = AppStateScope.of(context);
    await appState.saveMqttConfig(updated);
    if (!mounted) return;
    setState(() => _config = updated);

    final status = appState.connectionStatus.value;
    switch (status) {
      case MqttConnectionStatus.connected:
        _message('Connection saved and connected successfully.');
      case MqttConnectionStatus.authenticationFailure:
        _message('Connection saved, but authentication failed.', error: true);
      case MqttConnectionStatus.tlsFailure:
        _message('Connection saved, but TLS failed.', error: true);
      case MqttConnectionStatus.networkFailure:
        _message('Connection saved, but the broker could not be reached.', error: true);
      case MqttConnectionStatus.reconnecting:
        _message('Connection saved. Reconnecting…');
      case MqttConnectionStatus.connecting:
        _message('Connection saved. Connecting…');
      case MqttConnectionStatus.notConfigured:
        _message('Connection details are incomplete.', error: true);
      case MqttConnectionStatus.disconnected:
        _message('Connection saved, but the system is offline.', error: true);
    }
  }

  Future<void> _configureSafety() async {
    final draft = await showSafetyPolicyDialog(context, _lastSafety);
    if (draft == null || !mounted) return;

    final appState = AppStateScope.of(context);
    final outcome = await appState.applySafetyConfig(draft);
    if (!mounted) return;
    if (!outcome.isConfirmed) {
      _message(
        outcome.message ?? 'Central rejected the safety policy.',
        error: true,
      );
      return;
    }

    final values = <String, dynamic>{
      'minimumStateOfChargePercent': draft.lowBatteryCutoffPercent,
      'requiredRuntimeHours': draft.targetRuntimeHours,
      'maximumBatteryDischargeCurrentAmps': draft.maxBatteryDischargeCurrentA,
      'maximumMainCurrentAmps': draft.mainCurrentLimitA,
    };
    await appState.cacheLastInstallerSafetyConfig(values);
    if (!mounted) return;
    setState(() {
      _lastSafety = {
        ...values,
        'savedAt': DateTime.now().toIso8601String(),
      };
    });
    _message('Safety policy applied.');
  }

  Future<void> _configureBattery(InstallerNodeModel central) async {
    final draft = await showInstallerBatteryConfigDialog(context, _lastBattery);
    if (draft == null || !mounted) return;

    final appState = AppStateScope.of(context);
    final outcome = await appState.configureBatterySensor(
      centralNodeMac: central.mac,
      i2cAddress: 0x40,
      shuntResistanceOhms: draft.shuntResistanceOhms,
      nominalVoltageVolts: draft.nominalVoltageVolts,
      maximumExpectedCurrentAmps: draft.maximumExpectedCurrentAmps,
      emaAlpha: draft.emaAlpha,
      batteryCapacityAmpHours: draft.batteryCapacityAmpHours,
      initialStateOfChargePercent: draft.initialStateOfChargePercent,
    );
    if (!mounted) return;
    if (!outcome.isConfirmed) {
      _message(
        outcome.message ?? 'Central rejected the battery configuration.',
        error: true,
      );
      return;
    }

    final values = draft.toJson();
    await appState.cacheLastInstallerBatteryConfig(values);
    if (!mounted) return;
    setState(() {
      _lastBattery = {
        ...values,
        'savedAt': DateTime.now().toIso8601String(),
      };
    });
    _message('Battery monitor configuration applied.');
  }

  Future<void> _setSimulation(bool simulated) async {
    if (_sourceBusy) return;
    setState(() => _sourceBusy = true);
    final outcome = await AppStateScope.of(context).setSimulationEnabled(simulated);
    if (!mounted) return;
    setState(() => _sourceBusy = false);
    _message(
      outcome.isConfirmed
          ? (simulated ? 'Battery simulation enabled.' : 'INA219 input enabled.')
          : outcome.message ?? 'Central rejected the request.',
      error: !outcome.isConfirmed,
    );
  }

  Future<void> _setSimulationValues() async {
    final draft = await showSimulationInputDialog(context);
    if (draft == null || !mounted) return;
    final outcome = await AppStateScope.of(context).setSimulationValues(
      batteryVoltageVolts: draft.voltage,
      batteryCurrentAmps: draft.current,
      stateOfChargePercent: draft.soc,
    );
    if (!mounted) return;
    _message(
      outcome.isConfirmed
          ? 'Simulated battery readings applied.'
          : outcome.message ?? 'Central rejected the readings.',
      error: !outcome.isConfirmed,
    );
  }

  Future<void> _commission(
    InstallerNodeModel node, {
    bool rename = false,
  }) async {
    final controller = TextEditingController(text: rename ? node.name ?? '' : '');
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(rename ? 'Rename node' : 'Commission node'),
        content: SizedBox(
          width: 420,
          child: AppTextField(
            label: 'Node name',
            controller: controller,
            hintText: 'Kitchen node',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isEmpty || value.length >= 20) return;
              Navigator.of(dialogContext).pop(value);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || !mounted) return;

    final appState = AppStateScope.of(context);
    final outcome = rename
        ? await appState.renameNode(nodeMac: node.mac, friendlyName: name)
        : await appState.commissionNode(nodeMac: node.mac, friendlyName: name);
    if (!mounted) return;
    _message(
      outcome.isConfirmed
          ? (rename ? 'Node renamed.' : 'Node commissioned.')
          : outcome.message ?? 'Node rejected the request.',
      error: !outcome.isConfirmed,
    );
  }

  Future<void> _decommission(InstallerNodeModel node) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Decommission ${node.displayName}?'),
        content: const Text(
          'The node and its configured loads will be removed from this installation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Decommission'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final outcome = await AppStateScope.of(context).decommissionNode(nodeMac: node.mac);
    if (!mounted) return;
    _message(
      outcome.isConfirmed
          ? outcome.message ?? 'Node decommissioned.'
          : outcome.message ?? 'Could not decommission node.',
      error: !outcome.isConfirmed,
    );
  }

  Future<void> _addLoad(
    InstallerNodeModel node,
    List<LoadModel> nodeLoads,
  ) async {
    final usedPins = nodeLoads.map((load) => load.relayPin).toSet();
    final freePins = node.availableRelayPins
        .where((pin) => !usedPins.contains(pin))
        .toList();
    if (freePins.isEmpty) {
      _message('No free relay GPIOs are available on this node.', error: true);
      return;
    }

    final config = await showAddInstallerLoadDialog(
      context,
      node: node,
      freePins: freePins,
    );
    if (config == null || !mounted) return;

    final outcome = await AppStateScope.of(context).configureLoad(config);
    if (!mounted) return;
    _message(
      outcome.isConfirmed
          ? 'Load added to ${node.displayName}.'
          : outcome.message ?? 'Node rejected the load configuration.',
      error: !outcome.isConfirmed,
    );
  }

  Future<void> _editLoad(LoadModel load) async {
    if (_loadsBeingUpdated.contains(load.id)) return;
    final draft = await showLoadConfigurationDialog(context, load: load);
    if (draft == null || !mounted) return;

    setState(() => _loadsBeingUpdated.add(load.id));
    final outcome = await AppStateScope.of(context).updateLoadConfiguration(
      nodeMac: load.owningNodeMac,
      relayPin: load.relayPin,
      mode: draft.mode,
      currentRequestedState: load.requestedState ?? load.confirmedState ?? false,
      priority: draft.priority,
      schedule: draft.mode == LoadMode.fixed
          ? LoadSchedule.disabled
          : draft.schedule,
    );
    if (!mounted) return;
    setState(() => _loadsBeingUpdated.remove(load.id));

    _message(
      outcome.status == CommandStatus.confirmed
          ? '${load.name} configuration updated.'
          : outcome.message ?? 'Central rejected the load configuration.',
      error: outcome.status == CommandStatus.failed,
    );
  }

  Widget _content(BuildContext context) {
    final appState = AppStateScope.of(context);
    return AnimatedBuilder(
      animation: Listenable.merge([
        appState.connectionStatus,
        appState.systemState,
        appState.installerNodes,
        appState.loads,
      ]),
      builder: (context, _) {
        final nodes = appState.installerNodes.value;
        final loads = appState.loads.value;
        InstallerNodeModel? central;
        for (final node in nodes) {
          if (node.isCentralNode) {
            central = node;
            break;
          }
        }

        return ListView(
          children: [
            ResponsiveContent(
              maxWidth: 1320,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ResponsiveCardGrid(
                    minCardWidth: 330,
                    maxColumns: 3,
                    children: [
                      _brokerCard(appState.connectionStatus.value),
                      _batteryCard(central),
                      _safetyCard(),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    children: [
                      Expanded(
                        child: Text('Nodes & loads', style: AppTextStyles.title),
                      ),
                      Text(
                        '${nodes.length} nodes · ${loads.length} loads',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (nodes.isEmpty)
                    const SectionCard(
                      title: 'No nodes reported',
                      child: Text(
                        'Connect Central and wait for node identity reports.',
                        style: AppTextStyles.caption,
                      ),
                    )
                  else
                    ResponsiveCardGrid(
                      minCardWidth: 440,
                      maxColumns: 2,
                      children: [
                        for (final node in nodes)
                          _nodeCard(
                            node,
                            loads
                                .where((load) => load.owningNodeMac == node.mac)
                                .toList(),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      final loading = const Center(child: CircularProgressIndicator());
      if (widget.embedded) {
        return const Material(color: Colors.transparent, child: loading);
      }
      return const Scaffold(body: loading);
    }

    if (widget.embedded) {
      return Material(
        color: Colors.transparent,
        child: SafeArea(child: _content(context)),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Installer console')),
      body: SafeArea(child: _content(context)),
    );
  }

  Widget _brokerCard(MqttConnectionStatus status) {
    final config = _config!;
    return SectionCard(
      title: 'Connection',
      trailing: StatusBadge(
        label: _connectionLabel(status),
        tone: _connectionTone(status),
      ),
      child: config.isConfigured
          ? Column(
              children: [
                SectionRow(label: 'Host', value: config.host),
                SectionRow(label: 'Port', value: '${config.port}'),
                SectionRow(label: 'Namespace', value: config.topicNamespace),
                SectionRow(
                  label: 'Security',
                  value: config.useTls ? 'TLS' : 'No TLS',
                ),
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: _editBroker,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit'),
                  ),
                ),
              ],
            )
          : Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: _editBroker,
                icon: const Icon(Icons.add_link_outlined, size: 18),
                label: const Text('Add connection'),
              ),
            ),
    );
  }

  Widget _batteryCard(InstallerNodeModel? central) {
    final state = AppStateScope.of(context).systemState.value;
    final configured = state?.batterySensorConfigured == true;
    final simulated = state?.sensorInputSource?.toUpperCase() == 'SIMULATED';

    return SectionCard(
      title: 'Battery',
      trailing: StatusBadge(
        label: configured ? 'Configured' : 'Not configured',
        tone: configured ? StatusTone.positive : StatusTone.warning,
      ),
      child: Column(
        children: [
          SectionRow(label: 'Input', value: state?.sensorInputSource ?? 'Unavailable'),
          SectionRow(label: 'Voltage', value: Formatters.voltage(state?.batteryVoltage)),
          SectionRow(label: 'Current', value: Formatters.current(state?.batteryCurrent)),
          SectionRow(
            label: 'State of charge',
            value: Formatters.percent(state?.batterySocPercent),
          ),
          if (_lastBattery != null) ...[
            const Divider(),
            SectionRow(
              label: 'Nominal voltage',
              value: _numberText(_lastBattery, 'nominalVoltageVolts', ' V'),
            ),
            SectionRow(
              label: 'Capacity',
              value: _numberText(_lastBattery, 'batteryCapacityAmpHours', ' Ah'),
            ),
            SectionRow(label: 'Last applied', value: _savedAt(_lastBattery)),
          ],
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              OutlinedButton.icon(
                onPressed: central == null ? null : () => _configureBattery(central),
                icon: const Icon(Icons.tune_outlined, size: 18),
                label: Text(configured ? 'Configure' : 'Set up'),
              ),
              OutlinedButton(
                onPressed: _sourceBusy ? null : () => _setSimulation(!simulated),
                child: Text(
                  _sourceBusy
                      ? 'Applying…'
                      : (simulated ? 'Use INA219' : 'Simulate battery'),
                ),
              ),
              if (simulated)
                OutlinedButton(
                  onPressed: _setSimulationValues,
                  child: const Text('Set readings'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _safetyCard() {
    final hasSnapshot = _lastSafety != null;
    return SectionCard(
      title: 'Safety policy',
      trailing: StatusBadge(
        label: hasSnapshot ? 'Applied here' : 'Not available',
        tone: hasSnapshot ? StatusTone.info : StatusTone.neutral,
      ),
      child: Column(
        children: [
          if (hasSnapshot) ...[
            SectionRow(
              label: 'Minimum SoC',
              value: _numberText(
                _lastSafety,
                'minimumStateOfChargePercent',
                '%',
              ),
            ),
            SectionRow(
              label: 'Required runtime',
              value: _numberText(_lastSafety, 'requiredRuntimeHours', ' h'),
            ),
            SectionRow(
              label: 'Battery discharge',
              value: _numberText(
                _lastSafety,
                'maximumBatteryDischargeCurrentAmps',
                ' A',
              ),
            ),
            SectionRow(
              label: 'Main current',
              value: _numberText(_lastSafety, 'maximumMainCurrentAmps', ' A'),
            ),
            SectionRow(label: 'Last applied', value: _savedAt(_lastSafety)),
          ] else
            const SectionRow(
              label: 'Current values',
              value: 'Not published by Central',
              muted: true,
            ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: _configureSafety,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: Text(hasSnapshot ? 'Edit' : 'Configure'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _nodeCard(InstallerNodeModel node, List<LoadModel> nodeLoads) {
    final usedPins = nodeLoads.map((load) => load.relayPin).toSet();
    final freePins = node.availableRelayPins
        .where((pin) => !usedPins.contains(pin))
        .toList();
    final canAddLoad = node.isSmartNode && node.isCommissioned && freePins.isNotEmpty;

    return SectionCard(
      title: node.displayName,
      subtitle: node.mac,
      trailing: StatusBadge(
        label: node.online == true
            ? 'Online'
            : (node.online == false ? 'Offline' : node.lifecycleState),
        tone: node.online == true ? StatusTone.positive : StatusTone.warning,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionRow(label: 'Role', value: node.role),
          if (node.firmwareVersion != null)
            SectionRow(label: 'Firmware', value: node.firmwareVersion),
          if (node.isSmartNode)
            SectionRow(
              label: 'Relay GPIOs',
              value: node.availableRelayPins.isEmpty
                  ? 'None declared'
                  : node.availableRelayPins.join(', '),
            ),
          if (nodeLoads.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text('Loads', style: AppTextStyles.label),
            const SizedBox(height: AppSpacing.xs),
            for (final load in nodeLoads) _loadTile(load),
          ],
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              if (node.canBeCommissioned)
                FilledButton.icon(
                  onPressed: () => _commission(node),
                  icon: const Icon(Icons.add_link_outlined, size: 18),
                  label: const Text('Commission'),
                ),
              if (node.isCommissioned)
                OutlinedButton.icon(
                  onPressed: () => _commission(node, rename: true),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Rename'),
                ),
              if (node.isSmartNode && node.isCommissioned)
                OutlinedButton.icon(
                  onPressed: canAddLoad ? () => _addLoad(node, nodeLoads) : null,
                  icon: const Icon(Icons.add_outlined, size: 18),
                  label: Text(freePins.isEmpty ? 'No free relays' : 'Add load'),
                ),
              if (node.isSmartNode && node.isCommissioned)
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                  onPressed: () => _decommission(node),
                  icon: const Icon(Icons.link_off_outlined, size: 18),
                  label: const Text('Decommission'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _loadTile(LoadModel load) {
    final isOn = load.displayState == true;
    final busy = _loadsBeingUpdated.contains(load.id);
    final schedule = load.schedule.enabled
        ? '${Formatters.timeOfDay(load.schedule.startHour ?? 0, load.schedule.startMinute ?? 0)} – ${Formatters.timeOfDay(load.schedule.endHour ?? 0, load.schedule.endMinute ?? 0)}'
        : 'No schedule';

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: isOn ? AppColors.success : AppColors.error,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(load.name, style: AppTextStyles.label),
                const SizedBox(height: 2),
                Text(
                  'GPIO ${load.relayPin} · ${Formatters.power(load.plannedPowerW)} · ${load.mode == LoadMode.auto ? 'AUTO' : 'FIXED'} · Priority ${load.priority}/10',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption,
                ),
                if (load.mode == LoadMode.auto)
                  Text(schedule, style: AppTextStyles.caption),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          OutlinedButton.icon(
            onPressed: busy ? null : () => _editLoad(load),
            icon: busy
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.edit_outlined, size: 16),
            label: Text(busy ? 'Saving' : 'Edit'),
          ),
        ],
      ),
    );
  }

  String _numberText(Map<String, dynamic>? data, String key, String suffix) {
    final value = data?[key];
    if (value is num) {
      return '${value.toStringAsFixed(value % 1 == 0 ? 0 : 2)}$suffix';
    }
    return '—';
  }

  String _savedAt(Map<String, dynamic>? data) {
    final raw = data?['savedAt']?.toString();
    return Formatters.relativeTime(raw == null ? null : DateTime.tryParse(raw));
  }

  String _connectionLabel(MqttConnectionStatus status) {
    switch (status) {
      case MqttConnectionStatus.connected:
        return 'Connected';
      case MqttConnectionStatus.connecting:
        return 'Connecting';
      case MqttConnectionStatus.reconnecting:
        return 'Reconnecting';
      case MqttConnectionStatus.notConfigured:
        return 'Not configured';
      case MqttConnectionStatus.authenticationFailure:
        return 'Authentication failed';
      case MqttConnectionStatus.tlsFailure:
        return 'TLS failed';
      case MqttConnectionStatus.networkFailure:
        return 'Network unavailable';
      case MqttConnectionStatus.disconnected:
        return 'Disconnected';
    }
  }

  StatusTone _connectionTone(MqttConnectionStatus status) {
    switch (status) {
      case MqttConnectionStatus.connected:
        return StatusTone.positive;
      case MqttConnectionStatus.connecting:
      case MqttConnectionStatus.reconnecting:
        return StatusTone.info;
      case MqttConnectionStatus.notConfigured:
        return StatusTone.warning;
      default:
        return StatusTone.negative;
    }
  }
}
