import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../features/alerts/models/alert_model.dart';

/// Posts native Android notifications for alerts, alongside the in-app
/// notification list. Homeowner-only — the installer console never wires
/// this up since it has no alert stream of its own.
class LocalNotificationService {
  LocalNotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _channelId = 'kilowatts_alerts';
  static const _channelName = 'Kilowatts alerts';
  static const _channelDescription =
      'System alerts from your Kilowatts installation.';

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDescription,
            importance: Importance.high,
          ),
        );
  }

  Future<void> requestPermission() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  Future<void> showAlert(AlertModel alert) async {
    if (!_initialized) return;
    await _plugin.show(
      id: alert.id.hashCode,
      title: alert.title,
      body: alert.message,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }
}
