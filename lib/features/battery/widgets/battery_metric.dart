import 'package:flutter/material.dart';

import '../../../core/theme/app_text_styles.dart';

/// A compact label/value pair for the small stats beside the SoC gauge —
/// voltage, current, instantaneous battery power.
class BatteryMetric extends StatelessWidget {
  const BatteryMetric({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: AppTextStyles.caption),
        Text(
          value,
          style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
