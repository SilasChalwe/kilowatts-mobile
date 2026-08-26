import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../../core/services/mqtt_service.dart' show MqttConnectionStatus;
import '../../alerts/screens/alerts_screen.dart';
import '../../dashboard/screens/dashboard_screen.dart';
import '../../loads/screens/loads_screen.dart';
import '../../system/screens/system_topology_screen.dart';
import '../widgets/app_bottom_navigation.dart';
import 'more_screen.dart';

/// The persistent post-setup shell: four always-alive tabs plus a "More"
/// destination that pushes a separate menu screen rather than occupying a
/// fifth permanent tab slot.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  bool _didRequestConnect = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didRequestConnect) return;
    _didRequestConnect = true;

    final appState = AppStateScope.of(context);
    if (appState.connectionStatus.value == MqttConnectionStatus.disconnected ||
        appState.connectionStatus.value == MqttConnectionStatus.notConfigured) {
      appState.connectMqtt();
    }
  }

  void _handleDestinationTap(int index) {
    if (index == 4) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const MoreScreen()));
      return;
    }
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _currentIndex,
          children: [
            DashboardScreen(
              onViewAllAlerts: () => setState(() => _currentIndex = 3),
            ),
            const LoadsScreen(),
            const SystemTopologyScreen(),
            const AlertsScreen(),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNavigation(
        currentIndex: _currentIndex,
        onTap: _handleDestinationTap,
      ),
    );
  }
}
