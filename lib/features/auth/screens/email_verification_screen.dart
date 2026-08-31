import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/app_state/app_state.dart';
import '../../../core/app_state/app_state_scope.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/inline_message.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/secondary_button.dart';
import '../data/auth_failure.dart';
import '../widgets/auth_header.dart';
import '../widgets/auth_scaffold.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({required this.email, super.key});

  final String email;

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen>
    with WidgetsBindingObserver {
  static const int _resendCooldownSeconds = 60;

  late AppState _appState;
  Timer? _cooldownTimer;
  int _secondsRemaining = 0;
  bool _isChecking = false;
  bool _isResending = false;
  String? _message;
  bool _messageIsError = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _appState = AppStateScope.of(context);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cooldownTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_isChecking) {
      _checkVerification(silent: true);
    }
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _secondsRemaining = _resendCooldownSeconds);

    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_secondsRemaining <= 1) {
        timer.cancel();
        setState(() => _secondsRemaining = 0);
      } else {
        setState(() => _secondsRemaining -= 1);
      }
    });
  }

  Future<void> _checkVerification({bool silent = false}) async {
    if (_isChecking) return;

    setState(() {
      _isChecking = true;
      if (!silent) {
        _message = null;
      }
    });

    try {
      final verified = await _appState.authService
          .refreshEmailVerificationStatus();

      if (!mounted) return;

      if (verified) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil(AppRoutes.root, (_) => false);
        return;
      }

      if (!silent) {
        setState(() {
          _message =
              'Your email is not verified yet. Open the verification link, then try again.';
          _messageIsError = false;
        });
      }
    } catch (error) {
      if (!mounted || silent) return;
      setState(() {
        _message = AuthFailure.message(error, action: AuthAction.verification);
        _messageIsError = true;
      });
    } finally {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  Future<void> _resend() async {
    if (_secondsRemaining > 0 || _isResending) return;

    setState(() {
      _isResending = true;
      _message = null;
    });

    try {
      await _appState.authService.resendVerificationEmail();
      if (!mounted) return;

      _startCooldown();
      setState(() {
        _message = 'Verification email sent. Check your inbox and spam folder.';
        _messageIsError = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = AuthFailure.message(error, action: AuthAction.verification);
        _messageIsError = true;
      });
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  Future<void> _signOut() async {
    await _appState.signOut();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.root, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final resendLabel = _secondsRemaining > 0
        ? 'Resend in ${_secondsRemaining}s'
        : 'Resend Verification Email';

    return AuthScaffold(
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.md),
          CircleAvatar(
            radius: 44,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest,
            child: const Icon(Icons.verified_user_outlined, size: 42),
          ),
          const SizedBox(height: AppSpacing.lg),
          const AuthHeader(title: 'Verify Your Email'),
          const SizedBox(height: AppSpacing.md),
          Text(
            widget.email,
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xl),
          if (_message != null) ...[
            InlineMessage(message: _message!, isError: _messageIsError),
            const SizedBox(height: AppSpacing.md),
          ],
          PrimaryButton(
            label: 'I Have Verified My Email',
            isLoading: _isChecking,
            onPressed: () => _checkVerification(),
          ),
          const SizedBox(height: AppSpacing.sm),
          SecondaryButton(
            label: _isResending ? 'Sending...' : resendLabel,
            onPressed: _secondsRemaining == 0 && !_isResending ? _resend : null,
          ),
          const SizedBox(height: AppSpacing.md),
          TextButton(
            onPressed: _signOut,
            child: const Text('Use a Different Account'),
          ),
        ],
      ),
    );
  }
}
