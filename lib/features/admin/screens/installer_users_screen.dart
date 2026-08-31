import 'dart:async';

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
import 'installer_configuration_dialogs.dart';

class InstallerUsersScreen extends StatefulWidget {
  const InstallerUsersScreen({super.key, this.embedded = false, this.onSelect});

  final bool embedded;
  final ValueChanged<String>? onSelect;

  @override
  State<InstallerUsersScreen> createState() => _InstallerUsersScreenState();
}

class _InstallerUsersScreenState extends State<InstallerUsersScreen> {
  StreamSubscription<List<KilowattsUserAccess>>? _subscription;
  List<KilowattsUserAccess> _users = const [];
  bool _loading = true;
  bool _subscribed = false;
  Object? _loadError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_subscribed) return;
    _subscribed = true;
    _subscribe();
  }

  void _subscribe() {
    final appState = AppStateScope.of(context);
    _subscription = appState.watchAccessUsers().listen(
      (users) {
        if (!mounted) return;
        setState(() {
          _users = List.unmodifiable(users);
          _loading = false;
          _loadError = null;
        });
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          // Firestore can emit a cached snapshot before a later network/server
          // error. Never erase a directory that has already been received just
          // because a subsequent refresh fails. The full error state is only
          // appropriate when no usable user data has ever been available.
          _loading = false;
          _loadError = error;
        });
      },
    );
  }

  Future<void> _retry() async {
    await _subscription?.cancel();
    if (!mounted) return;
    setState(() {
      // Keep the last valid Firestore snapshot visible while the stream is
      // being re-established. Do not flash an empty/error page during retry.
      _loading = _users.isEmpty;
      _loadError = null;
    });
    _subscribe();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _openEditor([KilowattsUserAccess? existing]) async {
    final result = await showDialog<_AccessDraft>(
      context: context,
      builder: (_) => _AccessEditorDialog(existing: existing),
    );
    if (result == null || !mounted) return;

    try {
      await AppStateScope.of(context).saveAccessUser(
        email: result.email,
        fullName: result.fullName,
        phoneNumber: result.phoneNumber,
        role: result.role,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existing == null
                ? '${result.fullName} added to Kilowatts.'
                : '${result.fullName} updated.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      final message = error is ArgumentError
          ? error.message?.toString() ?? 'Invalid user details.'
          : 'Could not save this user.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _revoke(KilowattsUserAccess user) async {
    final currentEmail = AppStateScope.of(
      context,
    ).currentUser?.email?.toLowerCase();
    if (user.email.toLowerCase() == currentEmail) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Revoke access?'),
        content: Text(
          '${user.displayName} will no longer have Kilowatts access. Their sign-in account is not deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Revoke access'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await AppStateScope.of(context).revokeAccess(user.email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Access revoked for ${user.displayName}.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not revoke this user.')),
      );
    }
  }

  Future<void> _assignMqtt(KilowattsUserAccess user) async {
    final uid = user.uid;
    if (uid == null || uid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This user must sign in before MQTT can be assigned.'),
        ),
      );
      return;
    }

    final appState = AppStateScope.of(context);
    final existing = await appState.readSharedMqttConfig(uid);
    if (!mounted) return;
    final config = await showInstallerBrokerDialog(
      context,
      existing ??
          MqttConfig(host: '', port: 8883, webSocketPort: 8884, useTls: true),
    );
    if (config == null || !mounted) return;
    try {
      await appState.saveSharedMqttConfig(uid, config);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('MQTT assigned to ${user.displayName}.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not assign MQTT settings.')),
      );
    }
  }

  Widget _content(BuildContext context) {
    final currentEmail = AppStateScope.of(
      context,
    ).currentUser?.email?.toLowerCase();
    final hasUsers = _users.isNotEmpty;

    return ListView(
      children: [
        ResponsiveContent(
          maxWidth: 1180,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'User directory',
                      style: AppTextStyles.sectionTitle,
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => _openEditor(),
                    icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                    label: const Text('Add user'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              if (_loading && !hasUsers)
                const SectionCard(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                )
              else if (_loadError != null && !hasUsers)
                EmptyState(
                  icon: Icons.cloud_off_outlined,
                  title: 'User directory unavailable',
                  message: 'The user directory could not be loaded.',
                  action: OutlinedButton.icon(
                    onPressed: _retry,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Retry'),
                  ),
                )
              else if (!hasUsers)
                EmptyState(
                  icon: Icons.group_add_outlined,
                  title: 'No users registered',
                  message: 'Add the first user profile and access record.',
                  action: FilledButton.icon(
                    onPressed: () => _openEditor(),
                    icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                    label: const Text('Add user'),
                  ),
                )
              else
                SectionCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _DirectoryHeader(count: _users.length),
                      const Divider(height: 1),
                      for (var index = 0; index < _users.length; index++) ...[
                        _UserRow(
                          user: _users[index],
                          isCurrent:
                              _users[index].email.toLowerCase() == currentEmail,
                          onEdit: () => _openEditor(_users[index]),
                          onAssignMqtt: () => _assignMqtt(_users[index]),
                          onSelect:
                              widget.onSelect == null ||
                                  _users[index].uid == null
                              ? null
                              : () => widget.onSelect!(_users[index].uid!),
                          presenceStream: _users[index].uid != null
                              ? AppStateScope.of(context).watchMqttPresence(
                                  ownerUid: _users[index].uid!,
                                  userUid: _users[index].uid!,
                                )
                              : null,
                          onRevoke: () => _revoke(_users[index]),
                        ),
                        if (index != _users.length - 1)
                          const Divider(height: 1),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = SafeArea(child: _content(context));
    if (widget.embedded) {
      return Material(color: Colors.transparent, child: content);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Users & access')),
      body: content,
    );
  }
}

class _DirectoryHeader extends StatelessWidget {
  const _DirectoryHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Text('Users', style: AppTextStyles.label),
          const Spacer(),
          Text('$count total', style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

class _AccessDraft {
  const _AccessDraft({
    required this.email,
    required this.fullName,
    required this.phoneNumber,
    required this.role,
  });

  final String email;
  final String fullName;
  final String phoneNumber;
  final String role;
}

class _AccessEditorDialog extends StatefulWidget {
  const _AccessEditorDialog({this.existing});

  final KilowattsUserAccess? existing;

  @override
  State<_AccessEditorDialog> createState() => _AccessEditorDialogState();
}

class _AccessEditorDialogState extends State<_AccessEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _email;
  late final TextEditingController _fullName;
  late final TextEditingController _phone;
  late String _role;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.existing?.email ?? '');
    _fullName = TextEditingController(text: widget.existing?.fullName ?? '');
    _phone = TextEditingController(text: widget.existing?.phoneNumber ?? '');
    _role = switch (widget.existing?.role) {
      KilowattsRole.installer => 'installer',
      KilowattsRole.homeowner => 'homeowner',
      _ => 'unassigned',
    };
  }

  @override
  void dispose() {
    _email.dispose();
    _fullName.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      _AccessDraft(
        email: _email.text.trim().toLowerCase(),
        fullName: _fullName.text.trim(),
        phoneNumber: _phone.text.trim(),
        role: _role,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add user' : 'Edit user'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _fullName,
                  decoration: const InputDecoration(labelText: 'Full name'),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) => (value?.trim().length ?? 0) >= 2
                      ? null
                      : 'Enter the user name.',
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _email,
                  enabled: widget.existing == null,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    return email.contains('@') ? null : 'Enter a valid email.';
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _phone,
                  decoration: const InputDecoration(labelText: 'Phone number'),
                  keyboardType: TextInputType.phone,
                  validator: (value) => (value?.trim().length ?? 0) >= 7
                      ? null
                      : 'Enter a valid phone number.',
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  initialValue: _role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: const [
                    DropdownMenuItem(
                      value: 'unassigned',
                      child: Text('Unassigned'),
                    ),
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
        FilledButton(onPressed: _save, child: const Text('Save user')),
      ],
    );
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({
    required this.user,
    required this.isCurrent,
    required this.onEdit,
    required this.onAssignMqtt,
    required this.onSelect,
    required this.presenceStream,
    required this.onRevoke,
  });

  final KilowattsUserAccess user;
  final bool isCurrent;
  final VoidCallback onEdit;
  final VoidCallback onAssignMqtt;
  final VoidCallback? onSelect;
  final Stream<MqttPresence?>? presenceStream;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final isInstaller = user.role == KilowattsRole.installer;

    return InkWell(
      onTap: onSelect,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.primarySoft,
              child: Text(
                user.initials,
                style: AppTextStyles.label.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          user.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.label,
                        ),
                      ),
                      if (isCurrent) ...[
                        const SizedBox(width: AppSpacing.xs),
                        const _YouBadge(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    user.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
            if (MediaQuery.sizeOf(context).width >= 760) ...[
              Expanded(
                flex: 2,
                child: Text(
                  user.phoneNumber ?? 'Phone not recorded',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption,
                ),
              ),
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: StatusBadge(
                    label: user.roleLabel,
                    tone: isInstaller
                        ? StatusTone.info
                        : user.role == KilowattsRole.unassigned
                        ? StatusTone.warning
                        : StatusTone.neutral,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: presenceStream == null
                    ? const Text('App: no account', style: AppTextStyles.caption)
                    : StreamBuilder<MqttPresence?>(
                        stream: presenceStream,
                        builder: (context, snapshot) {
                          final presence = snapshot.data;
                          final online =
                              presence?.online == true &&
                              presence?.isFresh == true;
                          // Deliberately not "Online"/"Offline" — that pair
                          // is already used elsewhere for Central's own
                          // availability, a different signal from whether
                          // this specific person's own app is connected.
                          return StatusBadge(
                            label: presence == null
                                ? 'App: never connected'
                                : online
                                ? 'App: connected'
                                : 'App: not connected',
                            tone: online
                                ? StatusTone.positive
                                : StatusTone.neutral,
                          );
                        },
                      ),
              ),
              Expanded(
                child: Text(
                  user.uid ?? 'Not signed in',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption,
                ),
              ),
            ],
            PopupMenuButton<_UserAction>(
              tooltip: 'User actions',
              onSelected: (action) {
                if (action == _UserAction.edit) onEdit();
                if (action == _UserAction.assignMqtt) onAssignMqtt();
                if (action == _UserAction.revoke && !isCurrent) onRevoke();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: _UserAction.edit,
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Edit user'),
                  ),
                ),
                const PopupMenuItem(
                  value: _UserAction.assignMqtt,
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.wifi_tethering_outlined),
                    title: Text('Assign MQTT'),
                  ),
                ),
                PopupMenuItem(
                  value: _UserAction.revoke,
                  enabled: !isCurrent,
                  child: const ListTile(
                    dense: true,
                    leading: Icon(Icons.person_remove_outlined),
                    title: Text('Revoke access'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _UserAction { edit, assignMqtt, revoke }

class _YouBadge extends StatelessWidget {
  const _YouBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.infoSoft,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        'You',
        style: AppTextStyles.caption.copyWith(
          color: AppColors.info,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
