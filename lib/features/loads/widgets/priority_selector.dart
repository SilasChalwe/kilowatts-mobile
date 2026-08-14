import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/load_model.dart';

/// Backed by the raw 0-10 wire priority; the three segments are a display
/// convenience (see [LoadPriorityLevel]) that each send a representative
/// numeric value, not a wire-level enum.
class PrioritySelector extends StatelessWidget {
  const PrioritySelector({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final int value;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    final selectedLevel = LoadPriorityLevel.bucketFor(value);
    return SegmentedButton<LoadPriorityLevel>(
      segments: [
        for (final level in LoadPriorityLevel.values)
          ButtonSegment(value: level, label: Text(level.label)),
      ],
      selected: {selectedLevel},
      onSelectionChanged: onChanged == null
          ? null
          : (selection) => onChanged!(selection.first.wireValue),
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: AppColors.primary,
        selectedForegroundColor: Colors.white,
      ),
    );
  }
}
