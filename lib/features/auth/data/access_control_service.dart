import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// A Firestore `users/{email}` document is the authorization boundary for
/// the two UI products. Authentication alone proves a user has an account;
/// it must not grant installer-level hardware configuration rights.
/// Security rules (firestore.rules) restrict writes to that collection to
/// accounts that already hold the installer role, and restrict reads to the
/// owning account or an installer.
enum KilowattsRole { homeowner, installer, unassigned }

class InstallationAccess {
  const InstallationAccess({
    required this.role,
    this.installationId,
  });

  final KilowattsRole role;
  final String? installationId;

  bool get canManageHardware => role == KilowattsRole.installer;
}

class AccessControlService {
  AccessControlService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  static String _docIdFor(String email) => email.trim().toLowerCase();

  Future<InstallationAccess> resolve(User? user) async {
    final email = user?.email;
    if (email == null) {
      return const InstallationAccess(role: KilowattsRole.unassigned);
    }

    final snapshot = await _users.doc(_docIdFor(email)).get();
    final data = snapshot.data() ?? const <String, dynamic>{};
    final roleValue = data['role']?.toString().toLowerCase();
    final role = switch (roleValue) {
      'installer' || 'admin' => KilowattsRole.installer,
      'user' || 'homeowner' => KilowattsRole.homeowner,
      _ => KilowattsRole.unassigned,
    };
    final installationId = data['installationId']?.toString();
    return InstallationAccess(role: role, installationId: installationId);
  }

  /// Grants [role] ('installer' or 'homeowner') to the account with [email]
  /// by writing its Firestore role document. Security rules only allow this
  /// write when the signed-in caller already holds the installer role.
  Future<void> assignRole({
    required String email,
    required String role,
    String? installationId,
  }) {
    return _users.doc(_docIdFor(email)).set({
      'role': role,
      if (installationId != null && installationId.isNotEmpty)
        'installationId': installationId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
