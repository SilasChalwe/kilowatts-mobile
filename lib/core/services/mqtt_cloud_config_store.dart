import 'package:cloud_firestore/cloud_firestore.dart';

import 'mqtt_config.dart';

/// Installer-managed MQTT configuration for one physical installation.
class MqttCloudConfigStore {
  MqttCloudConfigStore({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _document(String installationId) =>
      _firestore
          .collection('installations')
          .doc(installationId)
          .collection('settings')
          .doc('mqtt');

  Future<MqttConfig?> read({required String installationId}) async {
    final id = installationId.trim();
    if (id.isEmpty) return null;
    final data = (await _document(id).get()).data();
    if (data == null) return null;
    return MqttConfig(
      host: data['host']?.toString() ?? '',
      port: (data['port'] as num?)?.toInt() ?? 8883,
      useTls: data['useTls'] as bool? ?? true,
      topicNamespace: data['topicNamespace']?.toString() ?? 'kilowatts/v1',
      username: data['username']?.toString(),
      password: data['password']?.toString(),
    );
  }

  Future<void> save(MqttConfig config, {required String installationId}) async {
    final id = installationId.trim();
    if (id.isEmpty) {
      throw ArgumentError('An installation ID is required.');
    }
    await _document(id).set({
      'host': config.host,
      'port': config.port,
      'useTls': config.useTls,
      'topicNamespace': config.topicNamespace,
      'username': config.username,
      'password': config.password,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> delete({required String installationId}) =>
      _document(installationId).delete();
}
