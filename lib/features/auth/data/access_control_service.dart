import 'package:firebase_auth/firebase_auth.dart';

/// Firebase custom claims are the authorization boundary for the two UI
/// products. Authentication alone proves a user has an account; it must not
/// grant installer-level hardware configuration rights.
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
  Future<InstallationAccess> resolve(User? user) async {
    if (user == null) {
      return const InstallationAccess(role: KilowattsRole.unassigned);
    }

    final token = await user.getIdTokenResult(true);
    final claims = token.claims ?? const <String, dynamic>{};
    final roleValue = claims['role']?.toString().toLowerCase();
    final role = switch (roleValue) {
      'installer' || 'admin' => KilowattsRole.installer,
      'user' || 'homeowner' => KilowattsRole.homeowner,
      _ => KilowattsRole.unassigned,
    };
    final installationId = claims['installationId']?.toString();
    return InstallationAccess(role: role, installationId: installationId);
  }
}
