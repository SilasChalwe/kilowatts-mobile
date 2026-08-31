import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/section_card.dart';
import '../../loads/widgets/load_mode_selector.dart';
import '../../loads/widgets/priority_selector.dart';
import '../models/setup_session.dart';

/// A single discovered Load the user is configuring during setup. The
/// relay identity (owning node + pin) is fixed — only name, priority and
/// mode are editable here.
class BranchAssignmentCard extends StatefulWidget {
  const BranchAssignmentCard({
    required this.draft,
    required this.loadLabel,
    super.key,
    this.onChanged,
  });

  final LoadConfigDraft draft;
  final String loadLabel;
  final VoidCallback? onChanged;

  @override
  State<BranchAssignmentCard> createState() => _BranchAssignmentCardState();
}

class _BranchAssignmentCardState extends State<BranchAssignmentCard> {
  late final _nameController = TextEditingController(text: widget.draft.name)
    ..addListener(_handleNameChanged);

  void _handleNameChanged() {
    widget.draft.name = _nameController.text;
    widget.onChanged?.call();
  }

  @override
  void dispose() {
    _nameController.removeListener(_handleNameChanged);
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: widget.loadLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTextField(label: 'Load Name', controller: _nameController),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Priority',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: AppSpacing.xs),
          PrioritySelector(
            value: widget.draft.priority,
            onChanged: (value) {
              setState(() => widget.draft.priority = value);
              widget.onChanged?.call();
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Mode',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: AppSpacing.xs),
          LoadModeSelector(
            value: widget.draft.mode,
            onChanged: (value) {
              setState(() => widget.draft.mode = value);
              widget.onChanged?.call();
            },
          ),
        ],
      ),
    );
  }
}
