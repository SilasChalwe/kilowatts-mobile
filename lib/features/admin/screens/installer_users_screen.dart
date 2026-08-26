import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/metric_card.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/responsive_content.dart';
import '../../../core/widgets/section_card.dart';
import '../../auth/data/access_control_service.dart';

class InstallerUsersScreen extends StatefulWidget {
  const InstallerUsersScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<InstallerUsersScreen> createState() => _InstallerUsersScreenState();
}

class _InstallerUsersScreenState extends State<InstallerUsersScreen> {
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
    return StreamBuilder<List<KilowattsUserAccess>>(
      stream: appState.watchAccessUsers(),
      builder: (context, snapshot) {
        final users = snapshot.data ?? const <KilowattsUserAccess>[];
        final homeowners = users
            .where((user) => user.role == KilowattsRole.homeowner)
            .toList();
        final installers = users
            .where((user) => user.role == KilowattsRole.installer)
            .toList();

        return ListView(
          children: [
            ResponsiveContent(
              maxWidth: 1200,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PageHeader(
                    eyebrow: 'Installation',
                    title: 'Users & access',
                    subtitle:
                        'Control who can operate this installation and who can administer it.',
                    actions: [
                      FilledButton.icon(
                        onPressed: _openEditor,
                        icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                        label: const Text('Add user'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData)
                    const SectionCard(
                      child: Row(
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: AppSpacing.sm),
                          Text('Loading access records…'),
                        ],
                      ),
                    )
                  else if (snapshot.hasError)
                    SectionCard(
                      title: 'Access records unavailable',
                      subtitle:
                          'The rest of the installer workspace remains available.',
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.errorSoft,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.cloud_off_outlined, color: AppColors.error),
                            SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                'Check Firestore permissions and network connectivity, then try this page again.',
                                style: AppTextStyles.caption,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else ...[
                    ResponsiveCardGrid(
                      minCardWidth: 210,
                      maxColumns: 3,
                      children: [
                        MetricCard(
                          label: 'Homeowners',
                          value: '${homeowners.length}',
                          icon: Icons.home_outlined,
                        ),
                        MetricCard(
                          label: 'Installers',
                          value: '${installers.length}',
                          icon: Icons.admin_panel_settings_outlined,
                        ),
                        MetricCard(
                          label: 'Accounts with access',
                          value: '${users.length}',
                          icon: Icons.people_outline,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ResponsiveCardGrid(
                      minCardWidth: 440,
                      maxColumns: 2,
                      children: [
                        _UserSection(
                          title: 'Homeowners',
                          subtitle: 'Operate the installation assigned to their account.',
                          users: homeowners,
                          currentEmail: appState.currentUser?.email,
                          onEdit: _openEditor,
                          onRevoke: _revoke,
                        ),
                        _UserSection(
                          title: 'Installers & administrators',
                          subtitle:
                              'Full homeowner controls plus commissioning and administration.',
                          users: installers,
                          currentEmail: appState.currentUser?.email,
                          onEdit: _openEditor,
                          onRevoke: _revoke,
                        ),
                      ],
                    ),
                  ],
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
      title: Text(widget.existing == null ? 'Add user access' : 'Edit access'),
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
                decoration: const InputDecoration(labelText: 'Account email'),
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
                  DropdownMenuItem(
                    value: 'installer',
                    child: Text('Installer / administrator'),
                  ),
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
              const SizedBox(height: AppSpacing.sm),
              Text(
                _role == 'installer'
                    ? 'Installers receive the full homeowner experience plus installation administration.'
                    : 'Homeowners can operate only the installation assigned above.',
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save access')),
      ],
    );
  }
}

class _UserSection extends StatelessWidget {
  const _UserSection({
    required this.title,
    required this.subtitle,
    required this.users,
    required this.currentEmail,
    required this.onEdit,
    required this.onRevoke,
  });

  final String title;
  final String subtitle;
  final List<KilowattsUserAccess> users;
  final String? currentEmail;
  final ValueChanged<KilowattsUserAccess> onEdit;
  final ValueChanged<KilowattsUserAccess> onRevoke;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: title,
      subtitle: subtitle,
      child: users.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                children: [
                  Icon(Icons.person_off_outlined, color: AppColors.textTertiary),
                  SizedBox(width: AppSpacing.sm),
                  Text('No accounts assigned.', style: AppTextStyles.caption),
                ],
              ),
            )
          : Column(
              children: [
                for (var index = 0; index < users.length; index++) ...[
                  _UserTile(
                    user: users[index],
                    isCurrent: users[index].email.toLowerCase() ==
                        currentEmail?.toLowerCase(),
                    onEdit: () => onEdit(users[index]),
                    onRevoke: () => onRevoke(users[index]),
                  ),
                  if (index != users.length - 1) const Divider(),
                ],
              ],
            ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: AppColors.primarySoft,
            child: Icon(
              user.role == KilowattsRole.installer
                  ? Icons.admin_panel_settings_outlined
                  : Icons.home_outlined,
              size: 19,
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
                const SizedBox(height: 2),
                Text(
                  user.role == KilowattsRole.homeowner
                      ? user.installationId ?? 'No installation assigned'
                      : 'Installer / administrator',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          PopupMenuButton<_UserAction>(
            tooltip: 'Access actions',
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
