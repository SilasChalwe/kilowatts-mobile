import 'package:flutter/material.dart';

import '../../../core/widgets/app_text_field.dart';

class PasswordField extends StatefulWidget {
  const PasswordField({
    required this.label,
    required this.controller,
    required this.validator,
    super.key,
    this.hintText = 'Enter your password',
    this.textInputAction,
    this.autofillHints,
    this.onFieldSubmitted,
    this.enabled = true,
  });

  final String label;
  final TextEditingController controller;
  final String? Function(String?) validator;
  final String hintText;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onFieldSubmitted;
  final bool enabled;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      label: widget.label,
      controller: widget.controller,
      hintText: widget.hintText,
      validator: widget.validator,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      obscureText: _obscure,
      enabled: widget.enabled,
      onFieldSubmitted: widget.onFieldSubmitted,
      prefixIcon: const Icon(Icons.lock_outline, size: 20),
      suffixIcon: IconButton(
        tooltip: _obscure ? 'Show password' : 'Hide password',
        onPressed: widget.enabled
            ? () => setState(() => _obscure = !_obscure)
            : null,
        icon: Icon(
          _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          size: 20,
        ),
      ),
    );
  }
}
