import 'package:flutter/material.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/primary_button.dart';
import '../widgets/auth_header.dart';
import '../widgets/auth_scaffold.dart';

class PasswordResetSentScreen extends StatelessWidget {
  const PasswordResetSentScreen({required this.email, super.key});

  final String email;

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      showBackButton: true,
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.md),
          CircleAvatar(
            radius: 44,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest,
            child: const Icon(Icons.mark_email_read_outlined, size: 42),
          ),
          const SizedBox(height: AppSpacing.lg),
          const AuthHeader(
            title: 'Check Your Email',
            subtitle:
                'If an account matches that email, Firebase will send password reset instructions.',
          ),
          if (email.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              email,
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          PrimaryButton(
            label: 'Back to Sign In',
            onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
              AppRoutes.login,
              (route) => route.settings.name == AppRoutes.root,
            ),
          ),
        ],
      ),
    );
  }
}
