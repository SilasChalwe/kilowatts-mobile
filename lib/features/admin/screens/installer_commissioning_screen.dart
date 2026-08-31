import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../../core/services/mqtt_config.dart';
import '../../../core/services/mqtt_presence_store.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/responsive_content.dart';
import '../../../core/widgets/section_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/data/access_control_service.dart';
import '../widgets/mqtt_configuration_dialog.dart';

class InstallerCommissioningScreen extends StatelessWidget {
  const InstallerCommissioningScreen({super.key});

  Future<void> _assignRole(
    BuildContext context,
    KilowattsUserAccess user,
  ) async {
    final uid = user.uid;
    if (uid == null) {
      _message(
        context,
        'This account has not signed in yet. Ask them to sign in, then retry.',
        true,
      );
      return;
    }
    final role = await showDialog<KilowattsRole>(
      context: context,
      builder: (dialogContext) => _RoleDialog(initialRole: user.role),
    );
    if (role == null || role == user.role || !context.mounted) return;
    try {
      await AppStateScope.of(
        context,
      ).setUserRole(email: user.email, uid: uid, role: role);
      if (context.mounted) _message(context, 'Role updated.');
    } catch (_) {
      if (context.mounted) {
        _message(context, 'Could not update role.', true);
      }
    }
  }

  Future<void> _configureMqtt(
    BuildContext context,
    KilowattsUserAccess user,
  ) async {
    final installationId = user.installationId;
    if (installationId == null) return;
    final appState = AppStateScope.of(context);
    final current = await appState.readSharedMqttConfig(installationId);
    if (!context.mounted) return;
    final config = await showMqttConfigurationDialog(
      context,
      current ??
          MqttConfig(
            host: '',
            port: 8883,
            useTls: true,
            topicNamespace: 'kilowatts/v1/$installationId',
          ),
    );
    if (config == null || !context.mounted) return;
    try {
      await appState.saveSharedMqttConfig(installationId, config);
      if (context.mounted) _message(context, 'MQTT settings saved.');
    } catch (_) {
      if (context.mounted) {
        _message(context, 'Could not save MQTT settings.', true);
      }
    }
  }

  Future<void> _revoke(BuildContext context, KilowattsUserAccess user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Revoke homeowner access?'),
        content: Text(
          '${user.displayName} will be disconnected from this installation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final uid = user.uid;
    if (uid == null) return;
    await AppStateScope.of(context).setUserRole(
      email: user.email,
      uid: uid,
      role: KilowattsRole.unassigned,
    );
  }

  static void _message(
    BuildContext context,
    String text, [
    bool error = false,
  ]) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: error ? AppColors.error : null,
        content: Text(text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Installer'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: appState.signOut,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<List<KilowattsUserAccess>>(
          stream: appState.watchAccessUsers(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const EmptyState(
                icon: Icons.cloud_off_outlined,
                title: 'Accounts unavailable',
                message: 'The user directory could not be loaded.',
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final users = snapshot.data!
                .where((user) => user.role != KilowattsRole.installer)
                .toList(growable: false);
            return ListView(
              children: [
                ResponsiveContent(
                  maxWidth: 920,
                  child: users.isEmpty
                      ? const EmptyState(
                          icon: Icons.person_add_alt_1_outlined,
                          title: 'No homeowner accounts',
                          message:
                              'The homeowner must register and verify an account before handover.',
                        )
                      : SectionCard(
                          padding: EdgeInsets.zero,
                          child: Column(
                            children: [
                              for (var i = 0; i < users.length; i++) ...[
                                _UserListTile(
                                  key: ValueKey(users[i].uid ?? users[i].email),
                                  user: users[i],
                                  onAssignRole: () =>
                                      _assignRole(context, users[i]),
                                  onMqtt: () =>
                                      _configureMqtt(context, users[i]),
                                  onRevoke: () => _revoke(context, users[i]),
                                ),
                                if (i != users.length - 1) const Divider(height: 1),
                              ],
                            ],
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

enum _UserAction { assignRole, mqtt, revoke }

class _UserListTile extends StatelessWidget {
  const _UserListTile({
    required this.user,
    required this.onAssignRole,
    required this.onMqtt,
    required this.onRevoke,
    super.key,
  });

  final KilowattsUserAccess user;
  final VoidCallback onAssignRole;
  final VoidCallback onMqtt;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final assigned = user.installationId != null;
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: CircleAvatar(
        radius: 16,
        child: Text(user.initials, style: AppTextStyles.caption),
      ),
      title: Text(user.displayName, style: AppTextStyles.label),
      subtitle: assigned
          ? StreamBuilder<MqttPresence?>(
              stream: AppStateScope.of(context).watchMqttPresence(
                installationId: user.installationId!,
                userUid: user.uid!,
              ),
              builder: (context, snapshot) {
                final presence = snapshot.data;
                final online =
                    presence?.online == true && presence?.isFresh == true;
                return Text(
                  online ? 'User online' : 'User not online',
                  style: AppTextStyles.caption.copyWith(
                    color: online ? AppColors.success : AppColors.textTertiary,
                  ),
                );
              },
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          StatusBadge(
            label: user.roleLabel,
            tone: assigned ? StatusTone.positive : StatusTone.warning,
            compact: true,
          ),
          const SizedBox(width: AppSpacing.xs),
          PopupMenuButton<_UserAction>(
            onSelected: (action) {
              switch (action) {
                case _UserAction.assignRole:
                  onAssignRole();
                case _UserAction.mqtt:
                  onMqtt();
                case _UserAction.revoke:
                  onRevoke();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: _UserAction.assignRole,
                child: Text('Assign role'),
              ),
              PopupMenuItem(
                value: _UserAction.mqtt,
                enabled: assigned,
                child: const Text('MQTT'),
              ),
              if (assigned)
                const PopupMenuItem(
                  value: _UserAction.revoke,
                  child: Text('Revoke'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoleDialog extends StatefulWidget {
  const _RoleDialog({required this.initialRole});

  final KilowattsRole initialRole;

  @override
  State<_RoleDialog> createState() => _RoleDialogState();
}

class _RoleDialogState extends State<_RoleDialog> {
  late KilowattsRole _role;

  @override
  void initState() {
    super.initState();
    _role = widget.initialRole;
  }

  static String _roleLabel(KilowattsRole role) => switch (role) {
    KilowattsRole.homeowner => 'Homeowner',
    KilowattsRole.installer => 'Installer',
    KilowattsRole.unassigned => 'Unassigned',
  };

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Assign role'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final role in KilowattsRole.values)
            RadioListTile<KilowattsRole>(
              contentPadding: EdgeInsets.zero,
              title: Text(_roleLabel(role)),
              value: role,
              groupValue: _role,
              onChanged: (value) => setState(() => _role = value!),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_role),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

