import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

class KilowattsUserAccess {
  const KilowattsUserAccess({
    required this.email,
    required this.role,
    this.installationId,
  });

  final String email;
  final KilowattsRole role;
  final String? installationId;

  String get roleLabel {
    switch (role) {
      case KilowattsRole.installer:
        return 'Installer';
      case KilowattsRole.homeowner:
        return 'Homeowner';
      case KilowattsRole.unassigned:
        return 'Unassigned';
    }
  }
}

/// Firestore `users/{email}` is the authorization boundary. Authentication
/// proves identity; this collection decides which installation and role that
/// identity can use. Firestore rules limit user-management writes to existing
/// installers.
class AccessControlService {
  AccessControlService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  static String _docIdFor(String email) => email.trim().toLowerCase();

  static KilowattsRole _parseRole(Object? value) {
    switch (value?.toString().toLowerCase()) {
      case 'installer':
      case 'admin':
        return KilowattsRole.installer;
      case 'user':
      case 'homeowner':
        return KilowattsRole.homeowner;
      default:
        return KilowattsRole.unassigned;
    }
  }

  Future<InstallationAccess> resolve(User? user) async {
    final email = user?.email;
    if (email == null) {
      return const InstallationAccess(role: KilowattsRole.unassigned);
    }

    final snapshot = await _users.doc(_docIdFor(email)).get();
    final data = snapshot.data() ?? const <String, dynamic>{};
    return InstallationAccess(
      role: _parseRole(data['role']),
      installationId: data['installationId']?.toString(),
    );
  }

  /// Live installer view of every account assigned to Kilowatts.
  Stream<List<KilowattsUserAccess>> watchUsers() {
    return _users.snapshots().map((snapshot) {
      final users = snapshot.docs.map((doc) {
        final data = doc.data();
        return KilowattsUserAccess(
          email: doc.id,
          role: _parseRole(data['role']),
          installationId: data['installationId']?.toString(),
        );
      }).toList();
      users.sort((a, b) => a.email.compareTo(b.email));
      return users;
    });
  }

  /// Grants or changes an account role. Homeowners must belong to a concrete
  /// installation; installers may span installations and therefore do not
  /// require an installation id.
  Future<void> assignRole({
    required String email,
    required String role,
    String? installationId,
  }) {
    final normalizedEmail = _docIdFor(email);
    final normalizedRole = role.trim().toLowerCase();
    if (normalizedEmail.isEmpty || !normalizedEmail.contains('@')) {
      throw ArgumentError('A valid account email is required.');
    }
    if (normalizedRole != 'installer' && normalizedRole != 'homeowner') {
      throw ArgumentError('Role must be installer or homeowner.');
    }

    final installation = installationId?.trim() ?? '';
    if (normalizedRole == 'homeowner' && installation.isEmpty) {
      throw ArgumentError('Homeowner access requires an installation ID.');
    }

    return _users.doc(normalizedEmail).set({
      'role': normalizedRole,
      if (normalizedRole == 'homeowner') 'installationId': installation,
      if (normalizedRole == 'installer') 'installationId': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> revokeAccess(String email) => _users.doc(_docIdFor(email)).delete();
}
