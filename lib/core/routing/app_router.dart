import 'package:flutter/material.dart';

import '../../features/auth/screens/auth_gate.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/password_reset_sent_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import 'app_routes.dart';

abstract final class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.root:
        return _page(settings, const AuthGate());
      case AppRoutes.login:
        return _page(settings, const LoginScreen());
      case AppRoutes.register:
        return _page(settings, const RegisterScreen());
      case AppRoutes.forgotPassword:
        return _page(settings, const ForgotPasswordScreen());
      case AppRoutes.resetEmailSent:
        final email = settings.arguments is String
            ? settings.arguments! as String
            : '';
        return _page(settings, PasswordResetSentScreen(email: email));
      default:
        return _page(settings, const AuthGate());
    }
  }

  static MaterialPageRoute<void> _page(RouteSettings settings, Widget child) {
    return MaterialPageRoute<void>(settings: settings, builder: (_) => child);
  }
}
