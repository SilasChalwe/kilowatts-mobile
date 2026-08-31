import 'package:flutter/material.dart';

import '../../../core/app_state/app_state.dart';
import '../../../core/app_state/app_state_scope.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/inline_message.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/auth_failure.dart';
import '../widgets/auth_header.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/password_field.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  late AppState _appState;

  bool _isSubmitting = false;
  bool _acceptedTerms = false;
  String? _errorMessage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _appState = AppStateScope.of(context);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_acceptedTerms) {
      setState(() {
        _errorMessage =
            'Please accept the Terms and Privacy Policy to continue.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await _appState.authService.createAccount(
        fullName: _nameController.text,
        email: _emailController.text,
        password: _passwordController.text,
      );

      if (!mounted) return;
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRoutes.root, (_) => false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = AuthFailure.message(error, action: AuthAction.register);
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
              const AuthHeader(title: 'Create Account'),
              const SizedBox(height: AppSpacing.xl),
              if (_errorMessage != null) ...[
                InlineMessage(message: _errorMessage!, isError: true),
                const SizedBox(height: AppSpacing.md),
              ],
              AppTextField(
                label: 'Full Name',
                controller: _nameController,
                hintText: 'Enter your full name',
                validator: Validators.fullName,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                enabled: !_isSubmitting,
                prefixIcon: const Icon(Icons.person_outline, size: 20),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Email',
                controller: _emailController,
                hintText: 'Enter your email',
                validator: Validators.email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [
                  AutofillHints.newUsername,
                  AutofillHints.email,
                ],
                enabled: !_isSubmitting,
                prefixIcon: const Icon(Icons.mail_outline, size: 20),
              ),
              const SizedBox(height: AppSpacing.md),
              PasswordField(
                label: 'Password',
                controller: _passwordController,
                validator: Validators.password,
                hintText: 'Create a password',
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                enabled: !_isSubmitting,
              ),
              const SizedBox(height: AppSpacing.xs),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Use 8+ characters with uppercase, lowercase and a number.',
                  style: AppTextStyles.caption,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              PasswordField(
                label: 'Confirm Password',
                controller: _confirmPasswordController,
                validator: (value) =>
                    Validators.confirmPassword(value, _passwordController.text),
                hintText: 'Confirm your password',
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                enabled: !_isSubmitting,
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: AppSpacing.sm),
              CheckboxListTile(
                value: _acceptedTerms,
                onChanged: _isSubmitting
                    ? null
                    : (value) =>
                          setState(() => _acceptedTerms = value ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                title: const Text(
                  'I agree to the Terms of Service and Privacy Policy.',
                  style: AppTextStyles.caption,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              PrimaryButton(
                label: 'Create Account',
                isLoading: _isSubmitting,
                onPressed: _submit,
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Already have an account?'),
                  TextButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(
                            context,
                          ).pushReplacementNamed(AppRoutes.login),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                    ),
                    child: const Text(
                      'Sign In',
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
