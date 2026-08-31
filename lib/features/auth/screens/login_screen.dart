import 'package:flutter/material.dart';

import '../../../core/app_state/app_state.dart';
import '../../../core/app_state/app_state_scope.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/inline_message.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/auth_failure.dart';
import '../widgets/auth_header.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/password_field.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
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
    _passwordController.dispose();
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

    try {
      await _appState.authService.signIn(
        email: _emailController.text,
        password: _passwordController.text,
      );

      if (!mounted) return;
      AppToast.show(context, message: 'Signed in.', tone: AppToastTone.success);
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRoutes.root, (_) => false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = AuthFailure.message(error, action: AuthAction.signIn);
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
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const AuthHeader(title: 'Welcome Back'),
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
                textInputAction: TextInputAction.next,
                autofillHints: const [
                  AutofillHints.username,
                  AutofillHints.email,
                ],
                enabled: !_isSubmitting,
                prefixIcon: const Icon(Icons.mail_outline, size: 20),
              ),
              const SizedBox(height: AppSpacing.md),
              PasswordField(
                label: 'Password',
                controller: _passwordController,
                validator: (value) =>
                    Validators.requiredField(value, fieldName: 'Password'),
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                enabled: !_isSubmitting,
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: AppSpacing.xs),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => Navigator.of(
                          context,
                        ).pushNamed(AppRoutes.forgotPassword),
                  child: const Text('Forgot Password?'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              PrimaryButton(
                label: 'Sign In',
                isLoading: _isSubmitting,
                onPressed: _submit,
              ),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.xxs,
                children: [
                  const Text('Don\'t have an account?'),
                  TextButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(
                            context,
                          ).pushReplacementNamed(AppRoutes.register),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                    ),
                    child: const Text(
                      'Create Account',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
