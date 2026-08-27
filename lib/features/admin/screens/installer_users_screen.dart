import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/responsive_content.dart';
import '../../../core/widgets/section_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/data/access_control_service.dart';

class InstallerUsersScreen extends StatefulWidget {
  const InstallerUsersScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<InstallerUsersScreen> createState() => _InstallerUsersScreenState();
}

class _InstallerUsersScreenState extends State<InstallerUsersScreen> {
  StreamSubscription<List<KilowattsUserAccess>>? _subscription;
  List<KilowattsUserAccess> _users = const [];
  bool _loading = true;
  bool _subscribed = false;
  Object? _refreshError;

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
          _refreshError = null;
        });
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _refreshError = error;
        });
      },
    );
  }

  Future<void> _retry() async {
    await _subscription?.cancel();
    if (!mounted) return;
    setState(() {
      _loading = _users.isEmpty;
      _refreshError = null;
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
      await AppStateScope.of(context).assignRole(
        email: result.email,
        role: result.role,
        installationId: result.installationId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Access saved for ${result.email}.')),
      );
    } catch (error) {
      if (!mounted) return;
      final message = error is ArgumentError
          ? error.message?.toString() ?? 'Invalid access configuration.'
          : 'Could not save access.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _revoke(KilowattsUserAccess user) async {
    final currentEmail = AppStateScope.of(context).currentUser?.email?.toLowerCase();
    if (user.email.toLowerCase() == currentEmail) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Revoke access?'),
        content: Text(
          '${user.email} will no longer be able to access this Kilowatts installation.',
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
        SnackBar(content: Text('Access revoked for ${user.email}.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not revoke access.')),
      );
    }
  }

  Widget _content(BuildContext context) {
    final appState = AppStateScope.of(context);
    final currentEmail = appState.currentUser?.email;

    return ListView(
      children: [
        ResponsiveContent(
          maxWidth: 1050,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                title: 'Users & access',
                actions: [
                  FilledButton.icon(
                    onPressed: _openEditor,
                    icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                    label: const Text('Add user'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_loading && _users.isEmpty)
                const SectionCard(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: AppSpacing.sm),
                        Text('Loading users…'),
                      ],
                    ),
                  ),
                )
              else if (_users.isEmpty && _refreshError != null)
                SectionCard(
                  title: 'Users unavailable',
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_off_outlined, color: AppColors.error),
                      const SizedBox(width: AppSpacing.sm),
                      const Expanded(
                        child: Text(
                          'The access list could not be loaded.',
                          style: AppTextStyles.caption,
                        ),
                      ),
                      OutlinedButton(onPressed: _retry, child: const Text('Retry')),
                    ],
                  ),
                )
              else ...[
                if (_refreshError != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warningSoft,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.sync_problem_outlined,
                          size: 18,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        const Expanded(
                          child: Text(
                            'Could not refresh users. Showing the last available list.',
                            style: AppTextStyles.caption,
                          ),
                        ),
                        TextButton(onPressed: _retry, child: const Text('Retry')),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                SectionCard(
                  title: 'Accounts',
                  trailing: Text(
                    '${_users.length}',
                    style: AppTextStyles.caption,
                  ),
                  child: Column(
                    children: [
                      for (var index = 0; index < _users.length; index++) ...[
                        _UserTile(
                          user: _users[index],
                          isCurrent: _users[index].email.toLowerCase() ==
                              currentEmail?.toLowerCase(),
                          onEdit: () => _openEditor(_users[index]),
                          onRevoke: () => _revoke(_users[index]),
                        ),
                        if (index != _users.length - 1) const Divider(),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return Material(
        color: Colors.transparent,
        child: SafeArea(child: _content(context)),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Users & access')),
      body: SafeArea(child: _content(context)),
    );
  }
}

class _AccessDraft {
  const _AccessDraft({
    required this.email,
    required this.role,
    this.installationId,
  });

  final String email;
  final String role;
  final String? installationId;
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
  late final TextEditingController _installation;
  late String _role;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.existing?.email ?? '');
    _installation = TextEditingController(
      text: widget.existing?.installationId ?? '',
    );
    _role = widget.existing?.role == KilowattsRole.installer
        ? 'installer'
        : 'homeowner';
  }

  @override
  void dispose() {
    _email.dispose();
    _installation.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      _AccessDraft(
        email: _email.text.trim(),
        role: _role,
        installationId: _role == 'homeowner'
            ? _installation.text.trim()
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add user' : 'Edit access'),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              DropdownButtonFormField<String>(
                initialValue: _role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: const [
                  DropdownMenuItem(value: 'homeowner', child: Text('Homeowner')),
                  DropdownMenuItem(value: 'installer', child: Text('Installer')),
                ],
                onChanged: (value) => setState(() => _role = value!),
              ),
              if (_role == 'homeowner') ...[
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _installation,
                  decoration: const InputDecoration(labelText: 'Installation ID'),
                  validator: (value) => value?.trim().isNotEmpty == true
                      ? null
                      : 'Installation ID is required.',
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({
    required this.user,
    required this.isCurrent,
    required this.onEdit,
    required this.onRevoke,
  });

  final KilowattsUserAccess user;
  final bool isCurrent;
  final VoidCallback onEdit;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final isInstaller = user.role == KilowattsRole.installer;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primarySoft,
            child: Icon(
              isInstaller
                  ? Icons.admin_panel_settings_outlined
                  : Icons.home_outlined,
              size: 20,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        user.email,
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
                const SizedBox(height: 4),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StatusBadge(
                      label: isInstaller ? 'Installer' : 'Homeowner',
                      tone: isInstaller ? StatusTone.info : StatusTone.neutral,
                    ),
                    if (!isInstaller && user.installationId != null)
                      Text(
                        user.installationId!,
                        style: AppTextStyles.caption,
                      ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<_UserAction>(
            tooltip: 'User actions',
            onSelected: (action) {
              if (action == _UserAction.edit) onEdit();
              if (action == _UserAction.revoke && !isCurrent) onRevoke();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: _UserAction.edit,
                child: Text('Edit access'),
              ),
              PopupMenuItem(
                value: _UserAction.revoke,
                enabled: !isCurrent,
                child: Text(isCurrent ? 'Current account' : 'Revoke access'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _UserAction { edit, revoke }

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
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
