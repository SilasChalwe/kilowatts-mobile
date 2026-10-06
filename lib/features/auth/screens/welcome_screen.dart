import 'package:flutter/material.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/kilowatts_logo.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/secondary_button.dart';
import '../widgets/auth_scaffold.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.lg),
          const KilowattsLogo(size: 150),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Kilowatts',
            textAlign: TextAlign.center,
            style: AppTextStyles.display.copyWith(fontSize: 28),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Smart solar load management for a safer and more efficient battery system.',
            textAlign: TextAlign.center,
            style: AppTextStyles.subtitle,
          ),
          const SizedBox(height: AppSpacing.xxl),
          PrimaryButton(
            label: 'Get Started',
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRoutes.register),
          ),
          const SizedBox(height: AppSpacing.sm),
          SecondaryButton(
            label: 'Sign In',
            onPressed: () => Navigator.of(context).pushNamed(AppRoutes.login),
          ),
          const SizedBox(height: AppSpacing.xl),
          const Text(
            'Monitor battery health, control loads and keep important appliances prioritised.',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}
