import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum KilowattsRole { homeowner, installer, unassigned }

class InstallationAccess {
  const InstallationAccess({
    required this.role,
    this.installationId,
    this.fullName,
    this.phoneNumber,
  });

  final KilowattsRole role;
  final String? installationId;
  final String? fullName;
  final String? phoneNumber;

  bool get canManageHardware => role == KilowattsRole.installer;
  bool get canManageUsers => role == KilowattsRole.installer;
}

class KilowattsUserAccess {
  const KilowattsUserAccess({
    required this.email,
    required this.role,
    this.installationId,
    this.fullName,
    this.phoneNumber,
  });

  final String email;
  final KilowattsRole role;
  final String? installationId;
  final String? fullName;
  final String? phoneNumber;

  String get displayName {
    final name = fullName?.trim() ?? '';
    return name.isEmpty ? email : name;
  }

  String get initials {
    final name = fullName?.trim() ?? '';
    final source = name.isEmpty ? email : name;
    final parts = source
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

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

/// Firestore `users/{email}` is the Kilowatts user directory and authorization
/// boundary. Firebase Authentication proves identity; this document stores the
/// installer-managed profile, role and installation assignment. Signed-in
/// users may read their own record, while only an existing installer may create,
/// edit or remove user records.
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

  static String? _optionalString(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
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
      installationId: _optionalString(data['installationId']),
      fullName: _optionalString(data['fullName']),
      phoneNumber: _optionalString(data['phoneNumber']),
    );
  }

  /// Live installer view of the Firestore user directory. The UI intentionally
  /// does not invent local fallback users when Firestore has not returned data.
  Stream<List<KilowattsUserAccess>> watchUsers() {
    return _users.snapshots().map((snapshot) {
      final users = snapshot.docs.map((doc) {
        final data = doc.data();
        return KilowattsUserAccess(
          email: doc.id,
          role: _parseRole(data['role']),
          installationId: _optionalString(data['installationId']),
          fullName: _optionalString(data['fullName']),
          phoneNumber: _optionalString(data['phoneNumber']),
        );
      }).toList();
      users.sort(
        (a, b) => a.displayName
            .toLowerCase()
            .compareTo(b.displayName.toLowerCase()),
      );
      return users;
    });
  }

  /// Registers a user or updates an existing user's profile/access record.
  /// Firestore rules allow this only for an existing installer account.
  Future<void> saveUser({
    required String email,
    required String fullName,
    required String phoneNumber,
    required String role,
    String? installationId,
  }) {
    final normalizedEmail = _docIdFor(email);
    final normalizedName = fullName.trim();
    final normalizedPhone = phoneNumber.trim();
    final normalizedRole = role.trim().toLowerCase();

    if (normalizedEmail.isEmpty || !normalizedEmail.contains('@')) {
      throw ArgumentError('A valid account email is required.');
    }
    if (normalizedName.length < 2) {
      throw ArgumentError('A user name is required.');
    }
    if (normalizedPhone.length < 7) {
      throw ArgumentError('A valid phone number is required.');
    }
    if (normalizedRole != 'installer' && normalizedRole != 'homeowner') {
      throw ArgumentError('Role must be installer or homeowner.');
    }

    final installation = installationId?.trim() ?? '';
    if (normalizedRole == 'homeowner' && installation.isEmpty) {
      throw ArgumentError('Homeowner access requires an installation ID.');
    }

    return _users.doc(normalizedEmail).set({
      'fullName': normalizedName,
      'phoneNumber': normalizedPhone,
      'role': normalizedRole,
      if (normalizedRole == 'homeowner') 'installationId': installation,
      if (normalizedRole == 'installer') 'installationId': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Role-only update retained for existing setup/integration call sites.
  /// It never fabricates missing name or phone profile values.
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

  Future<void> revokeAccess(String email) =>
      _users.doc(_docIdFor(email)).delete();
}
