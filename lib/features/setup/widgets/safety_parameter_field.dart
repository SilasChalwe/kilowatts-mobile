import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

/// A single numeric safety setting with its unit.
/// When [ceiling] is known, values above it are rejected — a configured
/// operating limit must never exceed a physical hardware ceiling.
class SafetyParameterField extends StatelessWidget {
  const SafetyParameterField({
    required this.label,
    required this.unit,
    required this.initialValue,
    required this.onChanged,
    super.key,
    this.ceiling,
    this.description,
  });

  final String label;
  final String? description;
  final String unit;
  final double initialValue;
  final double? ceiling;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.label),
                if (description != null) ...[
                  const SizedBox(height: 2),
                  Text(description!, style: AppTextStyles.caption),
                ],
                if (ceiling != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Hardware ceiling: ${ceiling!.toStringAsFixed(0)} $unit',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.warning,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          SizedBox(
            width: 96,
            child: TextFormField(
              initialValue: initialValue.toStringAsFixed(0),
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: false,
              ),
              decoration: InputDecoration(suffixText: unit),
              validator: (value) {
                final parsed = double.tryParse(value ?? '');
                if (parsed == null) return 'Invalid';
                if (ceiling != null && parsed > ceiling!) {
                  return 'Exceeds ceiling';
                }
                return null;
              },
              onChanged: (value) {
                final parsed = double.tryParse(value);
                if (parsed != null) onChanged(parsed);
              },
            ),
          ),
        ],
      ),
    );
  }
}
