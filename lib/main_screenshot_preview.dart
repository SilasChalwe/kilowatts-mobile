// TEMPORARY dev-only entry point: connects to the REAL MQTT broker with
// real credentials to screenshot the app against live data. Not part of
// the app; safe to delete. Do not commit real credentials elsewhere.
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'core/app_state/app_state.dart';
import 'core/app_state/app_state_scope.dart';
import 'core/services/local_state_service.dart';
import 'core/services/mqtt_service.dart';
import 'core/theme/app_theme.dart';
import 'features/admin/screens/installer_portal_screen.dart';
import 'features/auth/data/auth_service.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final appState = AppState(
    authService: AuthService(),
    mqttService: MqttService(),
    localStateService: LocalStateService(),
  );

  const config = MqttConfig(
    host: 'f3937cb6e5ab4814a9e88fe931c628af.s1.eu.hivemq.cloud',
    port: 8884,
    useTls: true,
    webSocketPath: '/mqtt',
    topicNamespace: 'kilowatts/v1',
    username: 'kilowatts',
    password: '********',
  );

  appState.saveMqttConfig(config);

  runApp(
    AppStateScope(
      appState: appState,
      child: MaterialApp(
        title: 'Kilowatts preview (LIVE)',
        theme: AppTheme.light(),
        home: const InstallerPortalScreen(),
      ),
    ),
  );
}
