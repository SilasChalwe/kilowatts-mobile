import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/page_header.dart';
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
          : 'Could not save access. Check Firestore connectivity and permissions.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _revoke(KilowattsUserAccess user) async {
    final currentEmail =
        AppStateScope.of(context).currentUser?.email?.toLowerCase();
    if (user.email.toLowerCase() == currentEmail) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Revoke access?'),
        content: Text(
          '${user.email} will no longer be able to access this Kilowatts system.',
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

  Widget _content(BuildContext context, {required bool showPageHeader}) {
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
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            if (showPageHeader) ...[
              PageHeader(
                title: 'Users & access',
                subtitle: 'Manage who can control and administer the installation.',
                actions: [
                  FilledButton.icon(
                    onPressed: () => _openEditor(),
                    icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                    label: const Text('Add user'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData)
              const SectionCard(
                child: Row(
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Text('Loading access records…'),
                  ],
                ),
              )
            else if (snapshot.hasError)
              _AccessStatusCard(
                onAdd: () => _openEditor(),
              )
            else ...[
              _summaryGrid(homeowners.length, installers.length, users.length),
              const SizedBox(height: AppSpacing.lg),
              if (users.isEmpty)
                SectionCard(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.people_outline_rounded,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'No users assigned yet',
                                style: AppTextStyles.label,
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Add a homeowner or another installer when you are ready.',
                                style: AppTextStyles.caption,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              FilledButton.icon(
                                onPressed: () => _openEditor(),
                                icon: const Icon(
                                  Icons.person_add_alt_1_outlined,
                                  size: 18,
                                ),
                                label: const Text('Add first user'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final twoColumns = constraints.maxWidth >= 900;
                    final gap = AppSpacing.md;
                    final width = twoColumns
                        ? (constraints.maxWidth - gap) / 2
                        : constraints.maxWidth;
                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      crossAxisAlignment: WrapCrossAlignment.start,
                      children: [
                        SizedBox(
                          width: width,
                          child: _UserSection(
                            title: 'Homeowners',
                            description:
                                'Accounts assigned to a specific installation.',
                            users: homeowners,
                            currentEmail: appState.currentUser?.email,
                            onEdit: _openEditor,
                            onRevoke: _revoke,
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: _UserSection(
                            title: 'Installers / administrators',
                            description:
                                'Accounts with homeowner controls and installation tools.',
                            users: installers,
                            currentEmail: appState.currentUser?.email,
                            onEdit: _openEditor,
                            onRevoke: _revoke,
                          ),
                        ),
                      ],
                    );
                  },
                ),
            ],
          ],
        );
      },
    );
  }

  Widget _summaryGrid(int homeowners, int installers, int total) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = AppSpacing.sm;
        final columns = constraints.maxWidth >= 720 ? 3 : 1;
        final width =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            SizedBox(
              width: width,
              child: _CountCard(
                icon: Icons.home_outlined,
                label: 'Homeowners',
                value: homeowners,
              ),
            ),
            SizedBox(
              width: width,
              child: _CountCard(
                icon: Icons.admin_panel_settings_outlined,
                label: 'Installers',
                value: installers,
              ),
            ),
            SizedBox(
              width: width,
              child: _CountCard(
                icon: Icons.people_outline,
                label: 'Total access',
                value: total,
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
        child: SafeArea(child: _content(context, showPageHeader: true)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Users & access'),
        actions: [
          IconButton(
            tooltip: 'Add user',
            onPressed: () => _openEditor(),
            icon: const Icon(Icons.person_add_alt_1_outlined),
          ),
        ],
      ),
      body: SafeArea(child: _content(context, showPageHeader: false)),
    );
  }
}

class _AccessStatusCard extends StatelessWidget {
  const _AccessStatusCard({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.cloud_off_outlined,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'User directory unavailable',
                    style: AppTextStyles.label,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'The app could not read Firestore access records. Check connectivity and installer permissions. The list will recover automatically when the connection returns.',
                    style: AppTextStyles.caption,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                    label: const Text('Add user anyway'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
        width: 480,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                  DropdownMenuItem(
                    value: 'homeowner',
                    child: Text('Homeowner'),
                  ),
                  DropdownMenuItem(
                    value: 'installer',
                    child: Text('Installer / Admin'),
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

class _CountCard extends StatelessWidget {
  const _CountCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: AppColors.textSecondary, size: 20),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$value', style: AppTextStyles.title),
              Text(label, style: AppTextStyles.caption),
            ],
          ),
        ],
      ),
    );
  }
}

class _UserSection extends StatelessWidget {
  const _UserSection({
    required this.title,
    required this.description,
    required this.users,
    required this.currentEmail,
    required this.onEdit,
    required this.onRevoke,
  });

  final String title;
  final String description;
  final List<KilowattsUserAccess> users;
  final String? currentEmail;
  final ValueChanged<KilowattsUserAccess> onEdit;
  final ValueChanged<KilowattsUserAccess> onRevoke;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(description, style: AppTextStyles.caption),
          const SizedBox(height: AppSpacing.md),
          if (users.isEmpty)
            const Text('None assigned.', style: AppTextStyles.caption)
          else
            ...users.map((user) {
              final isCurrent =
                  user.email.toLowerCase() == currentEmail?.toLowerCase();
              return Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    backgroundColor: AppColors.surface,
                    child: Icon(
                      user.role == KilowattsRole.installer
                          ? Icons.admin_panel_settings_outlined
                          : Icons.home_outlined,
                      size: 19,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  title: Row(
                    children: [
                      Flexible(child: Text(user.email)),
                      if (isCurrent) ...[
                        const SizedBox(width: AppSpacing.xs),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text('You', style: AppTextStyles.caption),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Text(
                    user.role == KilowattsRole.homeowner
                        ? user.installationId ?? 'No installation'
                        : 'Installer / Administrator',
                  ),
                  trailing: PopupMenuButton<_UserAction>(
                    onSelected: (action) {
                      if (action == _UserAction.edit) onEdit(user);
                      if (action == _UserAction.revoke && !isCurrent) {
                        onRevoke(user);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: _UserAction.edit,
                        child: Text('Edit access'),
                      ),
                      PopupMenuItem(
                        value: _UserAction.revoke,
                        enabled: !isCurrent,
                        child: Text(
                          isCurrent ? 'Current account' : 'Revoke access',
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

enum _UserAction { edit, revoke }
