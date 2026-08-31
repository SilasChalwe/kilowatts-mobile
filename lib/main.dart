import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/app_state/app_state.dart';
import 'core/services/local_notification_service.dart';
import 'core/services/local_state_service.dart';
import 'core/services/mqtt_cloud_config_store.dart';
import 'core/services/mqtt_presence_store.dart';
import 'core/services/mqtt_service.dart';
import 'core/services/telemetry_history_store.dart';
import 'features/auth/data/auth_service.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    final localStateService = LocalStateService();
    final authService = AuthService();

    final appState = AppState(
      authService: authService,
      mqttService: MqttService(cache: localStateService),
      localStateService: localStateService,
      mqttCloudConfigStore: MqttCloudConfigStore(),
      mqttPresenceStore: MqttPresenceStore(),
      telemetryHistoryStore: TelemetryHistoryStore(),
      localNotificationService: LocalNotificationService(),
    );

    runApp(KilowattsApp(appState: appState));
  } catch (error) {
    runApp(FirebaseBootstrapErrorApp(error: error));
  }
}

class FirebaseBootstrapErrorApp extends StatelessWidget {
  const FirebaseBootstrapErrorApp({required this.error, super.key});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_outlined, size: 64),
                    const SizedBox(height: 24),
                    const Text(
                      'Kilowatts could not connect to its account service',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Run FlutterFire configuration for this project, then rebuild the app.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    SelectableText(
                      error.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
