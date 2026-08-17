import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../../core/services/command_outcome.dart';
import '../../../core/services/mqtt_config.dart';
import '../../../core/services/mqtt_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/secondary_button.dart';
import '../../../core/widgets/section_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../models/installer_node_model.dart';
import '../../alerts/models/alert_model.dart';
import '../../alerts/widgets/alert_card.dart';
import '../../loads/models/load_model.dart';
import '../../setup/models/setup_session.dart';
import '../../system/screens/system_topology_screen.dart';

/// Flutter Web's installer-only cockpit. It is deliberately not part of the
/// mobile navigation: homeowner controls remain limited to monitoring,
/// preference and manual load actions while hardware commissioning happens
/// here on a wide screen.
class InstallerPortalScreen extends StatefulWidget {
  const InstallerPortalScreen({super.key});

  @override
  State<InstallerPortalScreen> createState() => _InstallerPortalScreenState();
}

class _InstallerPortalScreenState extends State<InstallerPortalScreen> {
  static const _destinations = <_PortalDestination>[
    _PortalDestination('Overview', Icons.space_dashboard_outlined),
    _PortalDestination('Connection', Icons.hub_outlined),
    _PortalDestination('Nodes & loads', Icons.account_tree_outlined),
    _PortalDestination('Topology', Icons.device_hub_outlined),
    _PortalDestination('Activity log', Icons.receipt_long_outlined),
    _PortalDestination('Safety policy', Icons.shield_outlined),
    _PortalDestination('Team access', Icons.admin_panel_settings_outlined),
  ];

  final _connectionFormKey = GlobalKey<FormState>();
  final _hostController = TextEditingController();
  final _portController = TextEditingController(text: '8884');
  final _webSocketPathController = TextEditingController(text: '/mqtt');
  final _topicNamespaceController = TextEditingController(text: 'kilowatts/v1');
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _savedPassword;
  bool _useTls = true;
  bool _savingConnection = false;
  bool _testingConnection = false;
  bool _togglingDevelopmentSession = false;
  int _selectedIndex = 0;
  bool _didInitialize = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInitialize) return;
    _didInitialize = true;
    _initialize();
  }

  Future<void> _initialize() async {
    final appState = AppStateScope.of(context);
    final config = await appState.loadMqttConfig();
    if (!mounted) return;
    _hostController.text = config.host;
    // The shared mobile default is raw MQTT/TLS (8883); a browser needs the
    // broker's WebSocket listener instead, commonly 8884. Keep a previously
    // saved installation value exactly, but do not prefill a new web install
    // with a TCP-only port.
    _portController.text = config.host.isEmpty ? '8884' : '${config.port}';
    _webSocketPathController.text = config.webSocketPath;
    _topicNamespaceController.text = config.topicNamespace;
    _usernameController.text = config.username ?? '';
    // A saved password must never be rendered back into a browser text
    // field. Leaving this blank keeps the existing secret on Save; entering
    // a value deliberately replaces it.
    _savedPassword = config.password;
    _passwordController.clear();
    setState(() => _useTls = config.useTls);
    await appState.connectMqtt();
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _webSocketPathController.dispose();
    _topicNamespaceController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  MqttConfig? _readConnectionForm() {
    if (!(_connectionFormKey.currentState?.validate() ?? false)) return null;
    final port = int.tryParse(_portController.text.trim());
    if (port == null || port < 1 || port > 65535) {
      _showMessage('Enter a valid broker port (1-65535).');
      return null;
    }
    return MqttConfig(
      host: _hostController.text.trim(),
      port: port,
      useTls: _useTls,
      webSocketPath: _webSocketPathController.text.trim(),
      topicNamespace: _topicNamespaceController.text.trim(),
      username: _emptyToNull(_usernameController.text),
      password: _emptyToNull(_passwordController.text) ?? _savedPassword,
    );
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _saveConnection() async {
    final config = _readConnectionForm();
    if (config == null) return;
    setState(() => _savingConnection = true);
    await AppStateScope.of(context).saveMqttConfig(config);
    if (!mounted) return;
    setState(() {
      _savingConnection = false;
      _savedPassword = config.password;
      _passwordController.clear();
    });
    _showMessage('Connection settings saved. Connecting to the Central Node…');
  }

  Future<void> _testConnection() async {
    final config = _readConnectionForm();
    if (config == null) return;
    setState(() => _testingConnection = true);
    final result = await AppStateScope.of(context).testMqttConnection(config);
    if (!mounted) return;
    setState(() => _testingConnection = false);
    _showMessage(
      result == MqttConnectionStatus.connected
          ? 'Broker connection succeeded.'
          : 'Broker test failed: ${_connectionLabel(result)}.',
    );
  }

  /// Starts or ends Central's Development Session — the only thing that
  /// switches the whole installation's Operating Environment between
  /// PRODUCTION and DEVELOPMENT (see [DevelopmentModeBadge], which is what
  /// the homeowner app shows as a result). Confirmed first since starting a
  /// session means every reading published afterwards is simulated, not
  /// real hardware, until explicitly ended.
  Future<void> _toggleDevelopmentSession(
    String centralNodeMac,
    bool start,
  ) async {
    final confirmed = await ConfirmationDialog.show(
      context,
      title: start ? 'Start Development Session?' : 'End Development Session?',
      message: start
          ? 'Switch to DEVELOPMENT mode?'
          : 'Switch to PRODUCTION mode?',
      confirmLabel: start ? 'Start session' : 'End session',
      isDestructive: !start,
    );
    if (!confirmed || !mounted) return;

    setState(() => _togglingDevelopmentSession = true);
    final outcome = await AppStateScope.of(
      context,
    ).setDevelopmentSession(centralNodeMac: centralNodeMac, start: start);
    if (!mounted) return;
    setState(() => _togglingDevelopmentSession = false);
    _showMessage(
      outcome.status == CommandStatus.confirmed
          ? (start
                ? 'Development Session started.'
                : 'Development Session ended.')
          : outcome.message ?? 'Central rejected the request.',
    );
  }

  InstallerNodeModel? _findCentralNode(List<InstallerNodeModel> nodes) {
    for (final node in nodes) {
      if (node.isCentralNode) return node;
    }
    return null;
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 900;
    return Scaffold(
      appBar: narrow
          ? AppBar(
              title: const Text('Kilowatts installer'),
              actions: [
                IconButton(
                  tooltip: 'Sign out',
                  onPressed: () => AppStateScope.of(context).signOut(),
                  icon: const Icon(Icons.logout),
                ),
              ],
            )
          : null,
      drawer: narrow ? _drawer(context) : null,
      body: Row(
        children: [
          if (!narrow) _rail(context),
          Expanded(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: _pageForSelection(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rail(BuildContext context) {
    return Container(
      width: 250,
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 32, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Kilowatts', style: AppTextStyles.title),
                SizedBox(height: 4),
                Text('Installer console', style: AppTextStyles.caption),
              ],
            ),
          ),
          Expanded(
            child: NavigationRail(
              extended: true,
              minExtendedWidth: 250,
              selectedIndex: _selectedIndex,
              onDestinationSelected: (value) =>
                  setState(() => _selectedIndex = value),
              destinations: [
                for (final item in _destinations)
                  NavigationRailDestination(
                    icon: Icon(item.icon),
                    selectedIcon: Icon(item.icon),
                    label: Text(item.label),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: TextButton.icon(
              onPressed: () => AppStateScope.of(context).signOut(),
              icon: const Icon(Icons.logout_outlined),
              label: const Text('Sign out'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawer(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          children: [
            const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Text('Installer console', style: AppTextStyles.title),
            ),
            for (var index = 0; index < _destinations.length; index++)
              ListTile(
                leading: Icon(_destinations[index].icon),
                title: Text(_destinations[index].label),
                selected: index == _selectedIndex,
                onTap: () {
                  setState(() => _selectedIndex = index);
                  Navigator.of(context).pop();
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _pageForSelection() {
    switch (_selectedIndex) {
      case 0:
        return _overviewPage();
      case 1:
        return _connectionPage();
      case 2:
        return _nodesPage();
      case 3:
        return const SystemTopologyScreen();
      case 4:
        return _activityLogPage();
      case 5:
        return _safetyPage();
      case 6:
        return _accessPage();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _activityLogPage() {
    final appState = AppStateScope.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Activity log', style: AppTextStyles.display),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: ValueListenableBuilder<List<AlertModel>>(
              valueListenable: appState.alerts,
              builder: (context, alerts, _) {
                if (alerts.isEmpty) {
                  return const EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No Activity Yet',
                    message: 'System events will appear here as they happen.',
                  );
                }
                return ListView.separated(
                  itemCount: alerts.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.xs),
                  itemBuilder: (context, index) =>
                      AlertCard(alert: alerts[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _overviewPage() {
    final appState = AppStateScope.of(context);
    return ListView(
      children: [
        const Text('Installation overview', style: AppTextStyles.display),
        const SizedBox(height: AppSpacing.xs),
        const Text(
          'Live broker status, discovered hardware and commissioning progress.',
          style: AppTextStyles.subtitle,
        ),
        const SizedBox(height: AppSpacing.md),
        AnimatedBuilder(
          animation: Listenable.merge([
            appState.connectionStatus,
            appState.lastLiveSystemUpdate,
          ]),
          builder: (context, _) {
            if (appState.isSystemStateLive) return const SizedBox.shrink();
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.sm),
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Central not reporting — everything below is last known data.',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.warning,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        AnimatedBuilder(
          animation: Listenable.merge([
            appState.connectionStatus,
            appState.lastLiveSystemUpdate,
          ]),
          builder: (context, _) {
            final status = appState.connectionStatus.value;
            final brokerLabel = status == MqttConnectionStatus.connected
                ? (appState.isSystemStateLive ? 'Connected' : 'No data yet')
                : _connectionLabel(status);
            final brokerTone = status == MqttConnectionStatus.connected
                ? (appState.isSystemStateLive
                      ? StatusTone.positive
                      : StatusTone.warning)
                : _connectionTone(status);
            return Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                _metricTile('Broker', brokerLabel, brokerTone),
                ValueListenableBuilder<List<InstallerNodeModel>>(
                  valueListenable: appState.installerNodes,
                  builder: (context, nodes, _) => _metricTile(
                    'Discovered nodes',
                    '${nodes.length}',
                    StatusTone.info,
                  ),
                ),
                ValueListenableBuilder(
                  valueListenable: appState.systemState,
                  builder: (context, state, _) => _metricTile(
                    'Battery sensor',
                    state?.batterySensorConfigured == true
                        ? 'Configured'
                        : 'Not configured',
                    state?.batterySensorConfigured == true
                        ? StatusTone.positive
                        : StatusTone.warning,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        ValueListenableBuilder<List<InstallerNodeModel>>(
          valueListenable: appState.installerNodes,
          builder: (context, nodes, _) {
            final centralNode = _findCentralNode(nodes);
            return ValueListenableBuilder(
              valueListenable: appState.systemState,
              builder: (context, state, _) {
                final isDevelopment =
                    state?.operatingEnvironment == 'DEVELOPMENT';
                return SectionCard(
                  title: 'Development mode',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          StatusBadge(
                            label: isDevelopment ? 'DEVELOPMENT' : 'PRODUCTION',
                            tone: isDevelopment
                                ? StatusTone.warning
                                : StatusTone.positive,
                          ),
                          const Spacer(),
                          if (centralNode == null)
                            const Text(
                              'Central Node not discovered yet.',
                              style: AppTextStyles.caption,
                            )
                          else if (_togglingDevelopmentSession)
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            SizedBox(
                              width: 220,
                              child: SecondaryButton(
                                label: isDevelopment
                                    ? 'End Development Session'
                                    : 'Start Development Session',
                                onPressed: () => _toggleDevelopmentSession(
                                  centralNode.mac,
                                  !isDevelopment,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        SectionCard(
          title: 'Commissioning order',
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('1. Connect this portal to the installation broker.'),
              SizedBox(height: AppSpacing.xs),
              Text('2. Commission each ESP-NOW-discovered Smart Node.'),
              SizedBox(height: AppSpacing.xs),
              Text(
                '3. Add verified relay, rated voltage/current, branch limit and startup facts for each load.',
              ),
              SizedBox(height: AppSpacing.xs),
              Text(
                '4. Apply the battery safety policy before enabling Auto loads.',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _metricTile(String label, String value, StatusTone tone) {
    return SizedBox(
      width: 210,
      child: SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTextStyles.caption),
            const SizedBox(height: AppSpacing.xs),
            Text(value, style: AppTextStyles.title),
            const SizedBox(height: AppSpacing.xs),
            StatusBadge(label: value, tone: tone),
          ],
        ),
      ),
    );
  }

  Widget _connectionPage() {
    return ListView(
      children: [
        const Text('Broker connection', style: AppTextStyles.display),
        const SizedBox(height: AppSpacing.xs),
        const Text(
          'This is installer-only infrastructure configuration. Browser builds require MQTT over WebSockets (WSS), not raw port 8883 TCP.',
          style: AppTextStyles.subtitle,
        ),
        const SizedBox(height: AppSpacing.lg),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: SectionCard(
            child: Form(
              key: _connectionFormKey,
              child: Column(
                children: [
                  AppTextField(
                    label: 'Broker host',
                    controller: _hostController,
                    hintText: 'broker.example.com',
                    validator: (value) {
                      final host = value?.trim() ?? '';
                      if (host.isEmpty) return 'Broker host is required.';
                      if (host.contains('://') ||
                          host.contains('/') ||
                          host.contains(':') ||
                          host.contains(RegExp(r'\s'))) {
                        return 'Enter only a host name, without a scheme, port or path.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          label: 'WebSocket port',
                          controller: _portController,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: AppTextField(
                          label: 'WebSocket path',
                          controller: _webSocketPathController,
                          hintText: '/mqtt',
                          validator: (value) {
                            final path = value?.trim() ?? '';
                            return path.isEmpty || !path.startsWith('/')
                                ? 'Use a path beginning with /.'
                                : null;
                          },
                        ),
                      ),
                    ],
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Use secure WSS / TLS'),
                    subtitle: const Text(
                      'Required for a public installer portal.',
                    ),
                    value: _useTls,
                    onChanged: (value) => setState(() => _useTls = value),
                  ),
                  AppTextField(
                    label: 'Central topic namespace',
                    controller: _topicNamespaceController,
                    hintText: 'kilowatts/v1/home-42',
                    validator: (value) {
                      final namespace = value?.trim() ?? '';
                      if (namespace.isEmpty)
                        return 'Topic namespace is required.';
                      if (namespace.startsWith('/') ||
                          namespace.endsWith('/') ||
                          namespace.contains('#') ||
                          namespace.contains('+')) {
                        return 'Use a concrete namespace without wildcards or edge slashes.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Must exactly match the namespace flashed into the Central Node; this portal does not rewrite embedded broker settings.',
                      style: AppTextStyles.caption,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    label: 'Broker username',
                    controller: _usernameController,
                    autofillHints: const [AutofillHints.username],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    label: 'Broker password',
                    controller: _passwordController,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    hintText: _savedPassword == null
                        ? null
                        : 'Saved securely — enter only to replace',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: SecondaryButton(
                          label: _testingConnection
                              ? 'Testing…'
                              : 'Test connection',
                          onPressed: _testingConnection
                              ? null
                              : _testConnection,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: PrimaryButton(
                          label: 'Save and connect',
                          isLoading: _savingConnection,
                          onPressed: _saveConnection,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _nodesPage() {
    final appState = AppStateScope.of(context);
    return ValueListenableBuilder<List<InstallerNodeModel>>(
      valueListenable: appState.installerNodes,
      builder: (context, nodes, _) {
        return ListView(
          children: [
            const Text('Nodes and loads', style: AppTextStyles.display),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Only firmware-declared relay GPIOs can be selected. A missing capability list means the board profile has not been verified and no load can be configured safely.',
              style: AppTextStyles.subtitle,
            ),
            const SizedBox(height: AppSpacing.lg),
            if (nodes.isEmpty)
              const SectionCard(
                child: Text(
                  'No Nodes received yet. Verify the broker connection and that the Central Node is online.',
                ),
              )
            else
              for (final node in nodes) ...[
                _nodeCard(node),
                const SizedBox(height: AppSpacing.md),
              ],
          ],
        );
      },
    );
  }

  Widget _nodeCard(InstallerNodeModel node) {
    final canConfigureLoad = node.isSmartNode && node.isCommissioned;
    return SectionCard(
      title: node.displayName,
      trailing: StatusBadge(
        label: node.lifecycleState,
        tone: node.isCommissioned ? StatusTone.positive : StatusTone.warning,
      ),
      child: Column(
        children: [
          SectionRow(label: 'MAC address', value: node.mac),
          SectionRow(label: 'Role', value: node.role),
          SectionRow(label: 'Firmware', value: node.firmwareVersion ?? '—'),
          SectionRow(label: 'Board', value: node.chipModel ?? '—'),
          SectionRow(
            label: 'Connection',
            value: node.online == null
                ? 'Unavailable'
                : (node.online!
                      ? (node.isCentralNode
                            ? 'Online'
                            : 'Online · ${node.hopCountToCentral ?? '?'} hop(s)')
                      : 'Offline'),
          ),
          SectionRow(
            label: 'Safe relay GPIOs',
            value: node.availableRelayPins.isEmpty
                ? 'None declared'
                : node.availableRelayPins.join(', '),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              if (node.canBeCommissioned)
                FilledButton.icon(
                  onPressed: () => _showCommissionDialog(node),
                  icon: const Icon(Icons.add_link),
                  label: const Text('Commission Node'),
                ),
              if (node.isCommissioned)
                OutlinedButton.icon(
                  onPressed: () => _showCommissionDialog(node, rename: true),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Rename'),
                ),
              if (node.isSmartNode && node.isCommissioned)
                OutlinedButton.icon(
                  onPressed: () => _showDecommissionDialog(node),
                  icon: const Icon(Icons.link_off_outlined),
                  label: const Text('Decommission'),
                ),
              if (canConfigureLoad)
                FilledButton.icon(
                  onPressed: node.availableRelayPins.isEmpty
                      ? null
                      : () => _showLoadDialog(node),
                  icon: const Icon(Icons.electrical_services_outlined),
                  label: const Text('Configure Load'),
                ),
              if (node.role == 'CENTRAL')
                OutlinedButton.icon(
                  onPressed: () => _showBatteryDialog(node),
                  icon: const Icon(Icons.battery_charging_full_outlined),
                  label: const Text('Configure Battery'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showCommissionDialog(
    InstallerNodeModel node, {
    bool rename = false,
  }) async {
    final nameController = TextEditingController(
      text: rename ? node.name ?? '' : '',
    );
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(rename ? 'Rename ${node.displayName}' : 'Commission Node'),
        content: SizedBox(
          width: 420,
          child: AppTextField(
            label: 'Friendly name',
            controller: nameController,
            hintText: 'Kitchen node',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty || name.length >= 20) {
                _showMessage('Enter a friendly name of 1-19 characters.');
                return;
              }
              final result = rename
                  ? await AppStateScope.of(
                      context,
                    ).renameNode(nodeMac: node.mac, friendlyName: name)
                  : await AppStateScope.of(
                      context,
                    ).commissionNode(nodeMac: node.mac, friendlyName: name);
              if (!context.mounted) return;
              if (result.isConfirmed) {
                Navigator.of(dialogContext).pop();
                _showMessage('Node configuration applied.');
              } else {
                _showMessage(
                  result.message ?? 'The Node rejected the request.',
                );
              }
            },
            child: Text(rename ? 'Rename' : 'Commission'),
          ),
        ],
      ),
    );
    nameController.dispose();
  }

  Future<void> _showLoadDialog(InstallerNodeModel node) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _ConfigureLoadDialog(node: node),
    );
  }

  Future<void> _showDecommissionDialog(InstallerNodeModel node) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Decommission ${node.displayName}?'),
        content: const Text(
          'Central removes its own record immediately. If this Node is reachable now, it will also turn all configured relays off and erase local load configuration. If the reset notification cannot be delivered, its local configuration remains until it is physically reset or later decommissioned while online.',
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

    final outcome = await AppStateScope.of(
      context,
    ).decommissionNode(nodeMac: node.mac);
    if (!mounted) return;
    _showMessage(
      outcome.isConfirmed
          ? outcome.message ?? 'Node removed from Central.'
          : outcome.message ?? 'Central could not decommission this Node.',
    );
  }

  Future<void> _showBatteryDialog(InstallerNodeModel node) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _ConfigureBatteryDialog(centralNode: node),
    );
  }

  Widget _safetyPage() {
    return const _SafetyPolicyForm();
  }

  Widget _accessPage() {
    return const _TeamAccessForm();
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

class _PortalDestination {
  const _PortalDestination(this.label, this.icon);

  final String label;
  final IconData icon;
}

class _ConfigureLoadDialog extends StatefulWidget {
  const _ConfigureLoadDialog({required this.node});

  final InstallerNodeModel node;

  @override
  State<_ConfigureLoadDialog> createState() => _ConfigureLoadDialogState();
}

class _ConfigureLoadDialogState extends State<_ConfigureLoadDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _nominalVoltage = TextEditingController();
  final _nominalCurrent = TextEditingController();
  final _branchMax = TextEditingController(text: '10');
  final _startupWatts = TextEditingController();
  final _priority = TextEditingController(text: '5');
  late int _relayPin;
  bool _activeHigh = false;
  LoadMode _mode = LoadMode.auto;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // The parent enables this dialog only for a node with a declared safe
    // capability. Keeping the selection here avoids ever inventing a GPIO.
    _relayPin = widget.node.availableRelayPins.first;
  }

  @override
  void dispose() {
    _name.dispose();
    _nominalVoltage.dispose();
    _nominalCurrent.dispose();
    _branchMax.dispose();
    _startupWatts.dispose();
    _priority.dispose();
    super.dispose();
  }

  double? _number(TextEditingController controller) =>
      double.tryParse(controller.text.trim());

  int? _integer(TextEditingController controller) {
    final value = controller.text.trim().toLowerCase();
    if (value.startsWith('0x'))
      return int.tryParse(value.substring(2), radix: 16);
    return int.tryParse(value);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final configuration = InstallerLoadConfiguration(
      nodeMac: widget.node.mac,
      name: _name.text.trim(),
      relayPin: _relayPin,
      relayActiveHigh: _activeHigh,
      nominalVoltageVolts: _number(_nominalVoltage)!,
      nominalCurrentAmps: _number(_nominalCurrent)!,
      branchMaximumCurrentAmps: _number(_branchMax)!,
      startupWatts: _number(_startupWatts)!,
      priority: _integer(_priority)!,
      mode: _mode,
    );
    setState(() {
      _saving = true;
      _error = null;
    });
    final outcome = await AppStateScope.of(
      context,
    ).configureLoad(configuration);
    if (!mounted) return;
    if (outcome.status == CommandStatus.confirmed) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Load hardware configuration applied.')),
      );
      return;
    }
    setState(() {
      _saving = false;
      _error = outcome.message ?? 'The Smart Node rejected this configuration.';
    });
  }

  String? _requiredNumber(
    String? value, {
    double min = 0,
    bool strictlyPositive = false,
  }) {
    final parsed = double.tryParse(value?.trim() ?? '');
    if (parsed == null ||
        !parsed.isFinite ||
        (strictlyPositive ? parsed <= min : parsed < min)) {
      return 'Enter a valid value.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Configure load on ${widget.node.displayName}'),
      content: SizedBox(
        width: 640,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'This Smart Node has no per-load INA219. Enter verified nameplate or commissioning-test ratings. The system derives planned running power as voltage × current; it is not a live per-load reading.',
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Load name',
                  controller: _name,
                  validator: (value) {
                    final trimmed = value?.trim() ?? '';
                    return trimmed.isEmpty || trimmed.length >= 16
                        ? 'Use 1-15 characters.'
                        : null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<int>(
                  initialValue: _relayPin,
                  decoration: const InputDecoration(
                    labelText: 'Verified relay GPIO',
                  ),
                  items: [
                    for (final pin in widget.node.availableRelayPins)
                      DropdownMenuItem(value: pin, child: Text('GPIO $pin')),
                  ],
                  onChanged: (value) => setState(() => _relayPin = value!),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active-high relay module'),
                  subtitle: const Text(
                    'Turn off for the common active-low relay boards.',
                  ),
                  value: _activeHigh,
                  onChanged: (value) => setState(() => _activeHigh = value),
                ),
                _twoFields(
                  AppTextField(
                    label: 'Rated voltage (V)',
                    controller: _nominalVoltage,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) =>
                        _requiredNumber(value, strictlyPositive: true),
                  ),
                  AppTextField(
                    label: 'Rated current (A)',
                    controller: _nominalCurrent,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) =>
                        _requiredNumber(value, strictlyPositive: true),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _twoFields(
                  AppTextField(
                    label: 'Branch limit (A)',
                    controller: _branchMax,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) =>
                        _requiredNumber(value, strictlyPositive: true),
                  ),
                  AppTextField(
                    label: 'Priority (0–10)',
                    controller: _priority,
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      final parsed = _integer(_priority);
                      return parsed == null || parsed < 0 || parsed > 10
                          ? 'Use 0–10.'
                          : null;
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _twoFields(
                  AppTextField(
                    label: 'Startup power (W)',
                    controller: _startupWatts,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) {
                      final startup = double.tryParse(value?.trim() ?? '');
                      final voltage = _number(_nominalVoltage);
                      final current = _number(_nominalCurrent);
                      final planned = voltage == null || current == null
                          ? null
                          : voltage * current;
                      return startup == null ||
                              planned == null ||
                              startup < planned
                          ? 'Must be ≥ rated V × A.'
                          : null;
                    },
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text('Running power is derived from rated V × A.'),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<LoadMode>(
                  initialValue: _mode,
                  decoration: const InputDecoration(
                    labelText: 'Initial operating mode',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: LoadMode.auto,
                      child: Text('Auto (initially off)'),
                    ),
                    DropdownMenuItem(
                      value: LoadMode.fixed,
                      child: Text('Fixed (initially off)'),
                    ),
                  ],
                  onChanged: (value) => setState(() => _mode = value!),
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(_error!, style: const TextStyle(color: AppColors.error)),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Apply hardware config'),
        ),
      ],
    );
  }

  Widget _twoFields(Widget first, Widget second) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: first),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: second),
      ],
    );
  }
}

/// Central's battery monitor is installed separately from Smart-Node load
/// channels. It has no relay GPIO, but it must still be commissioned with
/// real INA219 and battery-bank facts before automatic planning is allowed
/// to rely on its telemetry.
class _ConfigureBatteryDialog extends StatefulWidget {
  const _ConfigureBatteryDialog({required this.centralNode});

  final InstallerNodeModel centralNode;

  @override
  State<_ConfigureBatteryDialog> createState() =>
      _ConfigureBatteryDialogState();
}

class _ConfigureBatteryDialogState extends State<_ConfigureBatteryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _i2cAddress = TextEditingController(text: '0x40');
  final _shunt = TextEditingController(text: '0.005');
  final _nominalVoltage = TextEditingController(text: '12');
  final _maxCurrent = TextEditingController(text: '40');
  final _ema = TextEditingController(text: '0.2');
  final _capacity = TextEditingController(text: '100');
  final _initialSoc = TextEditingController(text: '80');
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _i2cAddress.dispose();
    _shunt.dispose();
    _nominalVoltage.dispose();
    _maxCurrent.dispose();
    _ema.dispose();
    _capacity.dispose();
    _initialSoc.dispose();
    super.dispose();
  }

  int? _integer(TextEditingController controller) {
    final value = controller.text.trim().toLowerCase();
    if (value.startsWith('0x'))
      return int.tryParse(value.substring(2), radix: 16);
    return int.tryParse(value);
  }

  double? _number(TextEditingController controller) =>
      double.tryParse(controller.text.trim());

  String? _positive(String? value) {
    final parsed = double.tryParse(value?.trim() ?? '');
    return parsed == null || !parsed.isFinite || parsed <= 0
        ? 'Enter a positive value.'
        : null;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final outcome = await AppStateScope.of(context).configureBatterySensor(
      centralNodeMac: widget.centralNode.mac,
      i2cAddress: _integer(_i2cAddress)!,
      shuntResistanceOhms: _number(_shunt)!,
      nominalVoltageVolts: _number(_nominalVoltage)!,
      maximumExpectedCurrentAmps: _number(_maxCurrent)!,
      emaAlpha: _number(_ema)!,
      batteryCapacityAmpHours: _number(_capacity)!,
      initialStateOfChargePercent: _number(_initialSoc)!,
    );
    if (!mounted) return;
    if (outcome.status == CommandStatus.confirmed) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Battery INA219 configuration applied.')),
      );
      return;
    }
    setState(() {
      _saving = false;
      _error = outcome.message ?? 'Central rejected the battery configuration.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Configure Central battery monitor'),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Enter the measured hardware values for the battery-bus INA219. These are installation facts; automatic load planning remains conservative until a real sensor reading arrives.',
                ),
                const SizedBox(height: AppSpacing.md),
                _twoFields(
                  AppTextField(
                    label: 'INA219 I²C address',
                    controller: _i2cAddress,
                    hintText: '0x40',
                    validator: (value) {
                      final parsed = _integer(_i2cAddress);
                      return parsed == null || parsed < 0x40 || parsed > 0x4f
                          ? 'Use 0x40–0x4F.'
                          : null;
                    },
                  ),
                  AppTextField(
                    label: 'Shunt resistance (Ω)',
                    controller: _shunt,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: _positive,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _twoFields(
                  AppTextField(
                    label: 'Nominal battery voltage (V)',
                    controller: _nominalVoltage,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: _positive,
                  ),
                  AppTextField(
                    label: 'Maximum sensor current (A)',
                    controller: _maxCurrent,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: _positive,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _twoFields(
                  AppTextField(
                    label: 'EMA alpha (0–1]',
                    controller: _ema,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) {
                      final parsed = double.tryParse(value?.trim() ?? '');
                      return parsed == null || parsed <= 0 || parsed > 1
                          ? 'Use a value > 0 and ≤ 1.'
                          : null;
                    },
                  ),
                  AppTextField(
                    label: 'Battery capacity (Ah)',
                    controller: _capacity,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: _positive,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Initial state of charge (%)',
                  controller: _initialSoc,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) {
                    final parsed = double.tryParse(value?.trim() ?? '');
                    return parsed == null || parsed < 0 || parsed > 100
                        ? 'Use 0–100.'
                        : null;
                  },
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(_error!, style: const TextStyle(color: AppColors.error)),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Apply battery config'),
        ),
      ],
    );
  }

  Widget _twoFields(Widget first, Widget second) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: first),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: second),
      ],
    );
  }
}

class _SafetyPolicyForm extends StatefulWidget {
  const _SafetyPolicyForm();

  @override
  State<_SafetyPolicyForm> createState() => _SafetyPolicyFormState();
}

class _SafetyPolicyFormState extends State<_SafetyPolicyForm> {
  final _formKey = GlobalKey<FormState>();
  final _minimumSoc = TextEditingController(text: '20');
  final _warningSoc = TextEditingController(text: '40');
  final _targetRuntime = TextEditingController(text: '4');
  final _safetyMargin = TextEditingController(text: '10');
  final _batteryCurrent = TextEditingController(text: '40');
  final _mainCurrent = TextEditingController(text: '30');
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _minimumSoc.dispose();
    _warningSoc.dispose();
    _targetRuntime.dispose();
    _safetyMargin.dispose();
    _batteryCurrent.dispose();
    _mainCurrent.dispose();
    super.dispose();
  }

  double _value(TextEditingController controller) =>
      double.parse(controller.text.trim());

  String? _positive(String? value) {
    final parsed = double.tryParse(value?.trim() ?? '');
    return parsed == null || !parsed.isFinite || parsed <= 0
        ? 'Enter a positive value.'
        : null;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_value(_warningSoc) < _value(_minimumSoc)) {
      setState(() => _error = 'Warning SoC must be at least the minimum SoC.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final result = await AppStateScope.of(context).applySafetyConfig(
      SafetyConfigDraft(
        lowBatteryCutoffPercent: _value(_minimumSoc),
        lowBatteryWarningPercent: _value(_warningSoc),
        targetRuntimeHours: _value(_targetRuntime),
        safetyMarginPercent: _value(_safetyMargin),
        maxBatteryDischargeCurrentA: _value(_batteryCurrent),
        mainCurrentLimitA: _value(_mainCurrent),
      ),
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _error = result.isConfirmed
          ? null
          : result.message ?? 'Central rejected the safety policy.';
    });
    if (result.isConfirmed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Safety policy applied and persisted on Central.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const Text('Safety policy', style: AppTextStyles.display),
        const SizedBox(height: AppSpacing.xs),
        const Text(
          'These limits are enforced by the Central Node before and during load planning. They are installation facts, not homeowner display preferences.',
          style: AppTextStyles.subtitle,
        ),
        const SizedBox(height: AppSpacing.lg),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: SectionCard(
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  _row(
                    AppTextField(
                      label: 'Minimum state of charge (%)',
                      controller: _minimumSoc,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (value) {
                        final parsed = double.tryParse(value?.trim() ?? '');
                        return parsed == null || parsed < 0 || parsed > 100
                            ? 'Use 0–100.'
                            : null;
                      },
                    ),
                    AppTextField(
                      label: 'Warning state of charge (%)',
                      controller: _warningSoc,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (value) {
                        final parsed = double.tryParse(value?.trim() ?? '');
                        return parsed == null || parsed < 0 || parsed > 100
                            ? 'Use 0–100.'
                            : null;
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _row(
                    AppTextField(
                      label: 'Target runtime (hours)',
                      controller: _targetRuntime,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: _positive,
                    ),
                    AppTextField(
                      label: 'Safety margin (%)',
                      controller: _safetyMargin,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (value) {
                        final parsed = double.tryParse(value?.trim() ?? '');
                        return parsed == null || parsed < 0 || parsed >= 100
                            ? 'Use 0–99.9.'
                            : null;
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _row(
                    AppTextField(
                      label: 'Maximum battery discharge (A)',
                      controller: _batteryCurrent,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: _positive,
                    ),
                    AppTextField(
                      label: 'Maximum main current (A)',
                      controller: _mainCurrent,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: _positive,
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      _error!,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  PrimaryButton(
                    label: 'Apply safety policy',
                    isLoading: _saving,
                    onPressed: _save,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _row(Widget first, Widget second) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: first),
      const SizedBox(width: AppSpacing.md),
      Expanded(child: second),
    ],
  );
}

/// Grants the `installer` or `homeowner` role to another Firebase account.
/// This is the only in-app path to setting the custom claims that
/// [AccessControlService] reads — everything here goes through the
/// `assignRole` Cloud Function, which itself requires the caller to already
/// hold the installer role.
class _TeamAccessForm extends StatefulWidget {
  const _TeamAccessForm();

  @override
  State<_TeamAccessForm> createState() => _TeamAccessFormState();
}

class _TeamAccessFormState extends State<_TeamAccessForm> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _installationId = TextEditingController();
  String _role = 'homeowner';
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _installationId.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await AppStateScope.of(context).assignRole(
        email: _email.text.trim(),
        role: _role,
        installationId: _installationId.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _email.clear();
        _installationId.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Granted $_role access to ${_email.text}.')),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.message ?? 'Firestore rejected this write.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not reach Firestore.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const Text('Team access', style: AppTextStyles.display),
        const SizedBox(height: AppSpacing.xs),
        const Text(
          'Grant installer or homeowner access to another account. Only accounts with installer access can do this.',
          style: AppTextStyles.subtitle,
        ),
        const SizedBox(height: AppSpacing.lg),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SectionCard(
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  AppTextField(
                    label: 'Account email',
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    validator: (value) {
                      final email = value?.trim() ?? '';
                      return email.contains('@')
                          ? null
                          : 'Enter a valid email address.';
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<String>(
                    initialValue: _role,
                    decoration: const InputDecoration(labelText: 'Role'),
                    items: const [
                      DropdownMenuItem(
                        value: 'homeowner',
                        child: Text('Homeowner'),
                      ),
                      DropdownMenuItem(
                        value: 'installer',
                        child: Text('Installer'),
                      ),
                    ],
                    onChanged: (value) => setState(() => _role = value!),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    label: 'Installation ID (homeowner only)',
                    controller: _installationId,
                    hintText: 'home-42',
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      _error!,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  PrimaryButton(
                    label: 'Grant access',
                    isLoading: _saving,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
