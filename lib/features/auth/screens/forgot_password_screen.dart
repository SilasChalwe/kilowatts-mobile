import 'package:flutter/material.dart';

import '../../../core/app_state/app_state.dart';
import '../../../core/app_state/app_state_scope.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/inline_message.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/auth_failure.dart';
import '../widgets/auth_header.dart';
import '../widgets/auth_scaffold.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  late AppState _appState;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _appState = AppStateScope.of(context);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final email = _emailController.text.trim();

    try {
      await _appState.authService.sendPasswordReset(email: email);

      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacementNamed(AppRoutes.resetEmailSent, arguments: email);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = AuthFailure.message(
          error,
          action: AuthAction.passwordReset,
        );
      });
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      showBackButton: true,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.md),
            CircleAvatar(
              radius: 44,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
              child: const Icon(Icons.lock_reset_rounded, size: 44),
            ),
            const SizedBox(height: AppSpacing.lg),
            const AuthHeader(
              title: 'Forgot Password?',
              subtitle:
                  'Enter your email and we will send password reset instructions.',
            ),
            const SizedBox(height: AppSpacing.xl),
            if (_errorMessage != null) ...[
              InlineMessage(message: _errorMessage!, isError: true),
              const SizedBox(height: AppSpacing.md),
            ],
            AppTextField(
              label: 'Email',
              controller: _emailController,
              hintText: 'Enter your email',
              validator: Validators.email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.email],
              enabled: !_isSubmitting,
              prefixIcon: const Icon(Icons.mail_outline, size: 20),
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: 'Send Reset Email',
              isLoading: _isSubmitting,
              onPressed: _submit,
            ),
            const SizedBox(height: AppSpacing.md),
            TextButton(
              onPressed: _isSubmitting
                  ? null
                  : () => Navigator.of(
                      context,
                    ).pushReplacementNamed(AppRoutes.login),
              child: const Text('Back to Sign In'),
            ),
          ],
        ),
      ),
    );
  }
}
