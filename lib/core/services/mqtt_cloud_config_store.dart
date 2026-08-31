import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'mqtt_config.dart';

/// Shared MQTT configuration for an installation.
///
/// The installer's configuration is stored once in Firestore so assigned
/// homeowners can restore it after signing in on a new device.
class MqttCloudConfigStore {
  MqttCloudConfigStore({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  DocumentReference<Map<String, dynamic>> _document(String uid) => _firestore
      .collection('installations')
      .doc(uid)
      .collection('settings')
      .doc('mqtt');

  Future<MqttConfig?> read({String? uid}) async {
    final id = uid ?? _auth.currentUser?.uid;
    if (id == null || id.isEmpty) return null;
    final snapshot = await _document(id).get();
    final data = snapshot.data();
    if (data == null) return null;
    final port = (data['port'] as num?)?.toInt() ?? 8883;
    final useTls = data['useTls'] as bool? ?? true;
    return MqttConfig(
      host: data['host']?.toString() ?? '',
      port: port,
      useTls: useTls,
      // Existing saved configurations predate the separate WebSocket port.
      // Preserve their former HiveMQ-compatible 8883 -> 8884 behaviour once,
      // then persist an explicit value the next time an installer saves.
      webSocketPort:
          (data['webSocketPort'] as num?)?.toInt() ??
          (useTls && port == 8883 ? 8884 : port),
      webSocketPath: data['webSocketPath']?.toString() ?? '/mqtt',
      topicNamespace: data['topicNamespace']?.toString() ?? 'kilowatts/v1',
      username: data['username']?.toString(),
      password: data['password']?.toString(),
    );
  }

  Future<void> save(MqttConfig config, {required String uid}) async {
    final id = uid.trim();
    if (id.isEmpty) {
      throw ArgumentError(
        'A Firebase user UID is required to share MQTT settings.',
      );
    }
    await _document(id).set({
      'host': config.host,
      'port': config.port,
      'useTls': config.useTls,
      'webSocketPort': config.resolvedWebSocketPort,
      'webSocketPath': config.webSocketPath,
      'topicNamespace': config.topicNamespace,
      'username': config.username,
      'password': config.password,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> delete({required String uid}) => _document(uid).delete();
}
