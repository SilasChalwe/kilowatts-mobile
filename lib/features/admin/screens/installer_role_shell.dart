import 'package:flutter/material.dart';

import '../../shell/screens/main_shell.dart';

/// Installer is a superset role. The same application shell is used for
/// everyday homeowner controls and installation administration so there is no
/// nested app bar, drawer or second navigation system.
class InstallerRoleShell extends StatelessWidget {
  const InstallerRoleShell({super.key});

  @override
  Widget build(BuildContext context) {
    return const MainShell(installerMode: true);
  }
}
