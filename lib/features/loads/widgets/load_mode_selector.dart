import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/load_model.dart';

class LoadModeSelector extends StatelessWidget {
  const LoadModeSelector({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final LoadMode value;
  final ValueChanged<LoadMode>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<LoadMode>(
      segments: const [
        ButtonSegment(value: LoadMode.auto, label: Text('Auto')),
        ButtonSegment(value: LoadMode.fixed, label: Text('Fixed')),
      ],
      selected: {value},
      onSelectionChanged: onChanged == null
          ? null
          : (selection) => onChanged!(selection.first),
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: AppColors.primary,
        selectedForegroundColor: Colors.white,
      ),
    );
  }
}
