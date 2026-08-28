import 'package:flutter/material.dart';

/// Kilowatts product colour system.
///
/// Accessibility rules:
/// - Normal text colours meet WCAG AA contrast on the light surfaces where
///   they are used.
/// - Semantic colours reinforce meaning but never carry meaning by themselves;
///   status UI must also use text, icons, labels or shape.
/// - Teal is reserved for product actions, focus and selection rather than
///   being reused as generic status decoration.
abstract final class AppColors {
  static const Color background = Color(0xFFF4F7F7);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceRaised = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFEEF3F3);
  static const Color surfaceAccent = Color(0xFFE7F3F4);

  static const Color textPrimary = Color(0xFF102124);
  static const Color textSecondary = Color(0xFF5E6D70);
  static const Color textTertiary = Color(0xFF6A777A);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  static const Color primary = Color(0xFF0F6F78);
  static const Color primaryHover = Color(0xFF0B6068);
  static const Color primaryPressed = Color(0xFF084E55);
  static const Color primarySoft = Color(0xFFE5F2F3);

  static const Color border = Color(0xFFDCE4E5);
  static const Color borderStrong = Color(0xFFC5D1D3);
  static const Color fieldFill = Color(0xFFFFFFFF);
  static const Color focus = Color(0xFF2A7F88);

  static const Color success = Color(0xFF24734D);
  static const Color successSoft = Color(0xFFEAF5EF);
  static const Color warning = Color(0xFF9A6208);
  static const Color warningSoft = Color(0xFFFFF5DF);
  static const Color error = Color(0xFFB42318);
  static const Color errorSoft = Color(0xFFFDEDEA);
  static const Color info = Color(0xFF275EA8);
  static const Color infoSoft = Color(0xFFEDF3FB);
  static const Color offline = Color(0xFF667579);

  static const Color sidebar = Color(0xFF102124);
  static const Color sidebarMuted = Color(0xFF1A3034);
  static const Color sidebarActive = Color(0xFF294246);
  static const Color sidebarText = Color(0xFFF6FAFA);
  static const Color sidebarTextMuted = Color(0xFFAFC0C3);
}
