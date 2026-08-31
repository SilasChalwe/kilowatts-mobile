import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/app_state/app_state.dart';
import '../../../core/app_state/app_state_scope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/kilowatts_logo.dart';
import '../../../core/widgets/status_badge.dart';
import '../../admin/screens/installer_console_screen.dart';
import '../../admin/screens/installer_operations_screen.dart';
import '../../admin/screens/installer_users_screen.dart';
import '../../alerts/models/alert_model.dart';
import '../../alerts/screens/alerts_screen.dart';
import '../../auth/data/access_control_service.dart';
import '../../battery/screens/battery_power_screen.dart';
import '../../dashboard/screens/dashboard_screen.dart';
import '../../history/screens/history_screen.dart';
import '../../loads/screens/loads_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../../system/screens/system_topology_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, this.installerMode = false});

  final bool installerMode;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final GlobalKey<ScaffoldState> _compactScaffoldKey =
      GlobalKey<ScaffoldState>();
  int _currentIndex = 0;
  bool _didRequestConnect = false;
  bool _didRestoreDestination = false;
  Future<InstallationAccess>? _profile;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didRequestConnect) return;
    _didRequestConnect = true;

    final appState = AppStateScope.of(context);
    _profile ??= appState.resolveCurrentAccess();
    if (!_didRestoreDestination) {
      _didRestoreDestination = true;
      _restoreDestination(appState);
    }
    if (appState.connectionStatus.value == MqttConnectionStatus.disconnected ||
        appState.connectionStatus.value == MqttConnectionStatus.notConfigured) {
      appState.connectMqtt();
    }
  }

  Future<void> _restoreDestination(AppState appState) async {
    final uid = appState.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final mode = widget.installerMode ? 'installer' : 'homeowner';
    final saved = prefs.getInt('kilowatts.destination.$mode.$uid');
    if (saved == null || saved < 0) return;
    final destinationCount = _destinations().length;
    if (saved >= destinationCount) return;
    setState(() => _currentIndex = saved);
  }

  List<_ProductDestination> _destinations() {
    final appState = AppStateScope.of(context);
    final selectedUserUid = appState.selectedUserUid;

    Widget userPage(String name, Widget child) {
      if (!widget.installerMode || selectedUserUid == null) return child;
      return KeyedSubtree(
        key: ValueKey('$name:$selectedUserUid'),
        child: child,
      );
    }

    final usersDestination = _ProductDestination(
      label: 'Users & access',
      icon: Icons.group_outlined,
      selectedIcon: Icons.group_rounded,
      page: InstallerUsersScreen(
        embedded: true,
        onSelect: (uid) {
          appState.selectUser(uid);
          setState(() => _currentIndex = 0);
        },
      ),
      installerOnly: true,
      showLiveStatus: false,
    );

    if (widget.installerMode && appState.selectedUserUid == null) {
      return [usersDestination];
    }

    return [
      _ProductDestination(
        label: 'Overview',
        icon: Icons.home_outlined,
        selectedIcon: Icons.home_rounded,
        page: userPage(
          'overview',
          DashboardScreen(
            onViewAllAlerts: () => setState(() => _currentIndex = 3),
          ),
        ),
      ),
      _ProductDestination(
        label: 'Loads',
        icon: Icons.bolt_outlined,
        selectedIcon: Icons.bolt_rounded,
        page: userPage('loads', const LoadsScreen()),
      ),
      _ProductDestination(
        label: 'House topology',
        icon: Icons.account_tree_outlined,
        selectedIcon: Icons.account_tree_rounded,
        page: userPage('topology', const SystemTopologyScreen()),
      ),
      _ProductDestination(
        label: 'Alerts',
        icon: Icons.notifications_outlined,
        selectedIcon: Icons.notifications_rounded,
        page: userPage('alerts', const AlertsScreen()),
        showUnreadBadge: true,
      ),
      _ProductDestination(
        label: 'Battery & power',
        icon: Icons.battery_charging_full_outlined,
        selectedIcon: Icons.battery_charging_full_rounded,
        page: userPage('battery', const BatteryPowerScreen(embedded: true)),
      ),
      _ProductDestination(
        label: 'Reports',
        icon: Icons.insights_outlined,
        selectedIcon: Icons.insights_rounded,
        page: userPage('reports', const HistoryScreen(embedded: true)),
        showLiveStatus: false,
      ),
      _ProductDestination(
        label: 'Settings',
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings_rounded,
        page: userPage('settings', const SettingsScreen(embedded: true)),
        showLiveStatus: false,
      ),
      if (widget.installerMode) ...[
        _ProductDestination(
          label: 'Installer console',
          icon: Icons.build_outlined,
          selectedIcon: Icons.build_rounded,
          page: userPage(
            'console',
            const InstallerConsoleScreen(embedded: true),
          ),
          installerOnly: true,
        ),
        _ProductDestination(
          label: 'System operations',
          icon: Icons.tune_outlined,
          selectedIcon: Icons.tune_rounded,
          page: userPage(
            'operations',
            const InstallerOperationsScreen(embedded: true),
          ),
          installerOnly: true,
        ),
        usersDestination,
      ],
    ];
  }

  void _selectDestination(int index, {bool closeDrawer = false}) {
    if (closeDrawer) Navigator.of(context).pop();
    setState(() => _currentIndex = index);
    final uid = AppStateScope.of(context).currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    final mode = widget.installerMode ? 'installer' : 'homeowner';
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setInt('kilowatts.destination.$mode.$uid', index),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final destinations = _destinations();
    final safeIndex = _currentIndex < destinations.length ? _currentIndex : 0;
    final current = destinations[safeIndex];

    return LayoutBuilder(
      builder: (context, constraints) {
        final usePersistentSidebar =
            kIsWeb && constraints.maxWidth >= AppBreakpoints.desktop;

        if (usePersistentSidebar) {
          return Scaffold(
            body: SafeArea(
              child: Row(
                children: [
                  SizedBox(
                    width: 264,
                    child: _NavigationPanel(
                      installerMode: widget.installerMode,
                      destinations: destinations,
                      selectedIndex: safeIndex,
                      profile: _profile!,
                      onSelect: _selectDestination,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        _DesktopUtilityBar(
                          title: current.label,
                          showLiveStatus: current.showLiveStatus,
                          userUid: widget.installerMode
                              ? appState.selectedUserUid
                              : null,
                        ),
                        Expanded(
                          child: IndexedStack(
                            index: safeIndex,
                            children: destinations
                                .map((item) => item.page)
                                .toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          key: _compactScaffoldKey,
          appBar: AppBar(
            backgroundColor: AppColors.surface,
            leading: IconButton(
              tooltip: 'Open navigation',
              onPressed: () => _compactScaffoldKey.currentState?.openDrawer(),
              icon: const Icon(Icons.menu_rounded),
            ),
            title: Text(current.label),
            actions: current.showLiveStatus
                ? const [
                    Padding(
                      padding: EdgeInsets.only(right: AppSpacing.sm),
                      child: _HeaderConnectionStatus(),
                    ),
                  ]
                : null,
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Divider(height: 1),
            ),
          ),
          drawer: Drawer(
            width: 292,
            backgroundColor: AppColors.sidebar,
            child: SafeArea(
              child: _NavigationPanel(
                installerMode: widget.installerMode,
                destinations: destinations,
                selectedIndex: safeIndex,
                profile: _profile!,
                onSelect: (index) =>
                    _selectDestination(index, closeDrawer: true),
              ),
            ),
          ),
          body: IndexedStack(
            index: safeIndex,
            children: destinations.map((item) => item.page).toList(),
          ),
        );
      },
    );
  }
}

class _DesktopUtilityBar extends StatelessWidget {
  const _DesktopUtilityBar({
    required this.title,
    required this.showLiveStatus,
    this.userUid,
  });

  final String title;
  final bool showLiveStatus;
  final String? userUid;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(child: Text(title, style: AppTextStyles.title)),
          if (userUid != null) ...[
            StatusBadge(label: userUid!, tone: StatusTone.neutral),
            const SizedBox(width: AppSpacing.sm),
          ],
          if (showLiveStatus) const _HeaderConnectionStatus(),
        ],
      ),
    );
  }
}

class _HeaderConnectionStatus extends StatelessWidget {
  const _HeaderConnectionStatus();

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    return AnimatedBuilder(
      animation: Listenable.merge([
        appState.connectionStatus,
        appState.lastLiveSystemUpdate,
      ]),
      builder: (context, _) {
        final live = appState.isSystemStateLive;
        final color = live ? AppColors.success : AppColors.offline;
        final label = live ? 'Online' : 'Offline';
        final icon = live
            ? Icons.cloud_done_outlined
            : Icons.cloud_off_outlined;

        return Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: color.withValues(alpha: 0.18)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 7),
              Text(label, style: AppTextStyles.caption),
            ],
          ),
        );
      },
    );
  }
}

class _ProductDestination {
  const _ProductDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.page,
    this.installerOnly = false,
    this.showLiveStatus = true,
    this.showUnreadBadge = false,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget page;
  final bool installerOnly;
  final bool showLiveStatus;
  final bool showUnreadBadge;
}

class _NavigationPanel extends StatelessWidget {
  const _NavigationPanel({
    required this.installerMode,
    required this.destinations,
    required this.selectedIndex,
    required this.profile,
    required this.onSelect,
  });

  final bool installerMode;
  final List<_ProductDestination> destinations;
  final int selectedIndex;
  final Future<InstallationAccess> profile;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final firstInstaller = destinations.indexWhere(
      (item) => item.installerOnly,
    );

    return ColoredBox(
      color: AppColors.sidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  padding: const EdgeInsets.all(5),
                  child: const KilowattsLogo(size: 28),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Kilowatts',
                    style: AppTextStyles.sectionTitle.copyWith(
                      color: AppColors.sidebarText,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: [
                for (var i = 0; i < destinations.length; i++) ...[
                  if (i == firstInstaller && firstInstaller >= 0) ...[
                    const SizedBox(height: AppSpacing.md),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                      child: Text(
                        'INSTALLATION',
                        style: AppTextStyles.overline.copyWith(
                          color: AppColors.sidebarTextMuted,
                        ),
                      ),
                    ),
                  ],
                  _SidebarDestination(
                    destination: destinations[i],
                    selected: selectedIndex == i,
                    onTap: () => onSelect(i),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
            child: FutureBuilder<InstallationAccess>(
              future: profile,
              builder: (context, snapshot) {
                final profile = snapshot.data;
                final email = appState.currentUser?.email;
                final name = profile?.fullName?.trim();
                final displayName = name?.isNotEmpty == true
                    ? name!
                    : email ?? 'Signed in';
                final roleLabel = profile == null
                    ? (installerMode ? 'Installer' : 'Homeowner')
                    : _roleLabel(profile.role);

                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.sidebarMuted,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.primary,
                        child: Text(
                          _initials(name, email),
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.label.copyWith(
                                color: AppColors.sidebarText,
                              ),
                            ),
                            Text(
                              roleLabel,
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.sidebarTextMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Sign out',
                        onPressed: appState.signOut,
                        icon: const Icon(Icons.logout_rounded, size: 18),
                        color: AppColors.sidebarTextMuted,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static String _roleLabel(KilowattsRole role) {
    switch (role) {
      case KilowattsRole.installer:
        return 'Installer';
      case KilowattsRole.homeowner:
        return 'Homeowner';
      case KilowattsRole.unassigned:
        return 'Unassigned';
    }
  }

  static String _initials(String? name, String? email) {
    final source = name?.trim().isNotEmpty == true
        ? name!.trim()
        : email?.trim() ?? '';
    if (source.isEmpty) return '?';
    final parts = source
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }
}

class _SidebarDestination extends StatelessWidget {
  const _SidebarDestination({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _ProductDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected
        ? AppColors.sidebarText
        : AppColors.sidebarTextMuted;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? AppColors.sidebarActive : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  selected ? destination.selectedIcon : destination.icon,
                  size: 20,
                  color: foreground,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    destination.label,
                    style: AppTextStyles.label.copyWith(color: foreground),
                  ),
                ),
                if (destination.showUnreadBadge)
                  ValueListenableBuilder<List<AlertModel>>(
                    valueListenable: AppStateScope.of(context).alerts,
                    builder: (context, alerts, _) {
                      final unread = alerts
                          .where((alert) => !alert.acknowledged)
                          .length;
                      if (unread == 0) return const SizedBox.shrink();
                      return Container(
                        constraints: const BoxConstraints(minWidth: 22),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: selected ? AppColors.primary : AppColors.error,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          unread > 99 ? '99+' : '$unread',
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
