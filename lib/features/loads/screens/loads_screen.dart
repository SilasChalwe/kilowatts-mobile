import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/empty_state.dart';
import '../models/load_model.dart';
import '../widgets/load_card.dart';
import 'load_details_screen.dart';

enum _LoadFilter { all, fixed, auto, on, off, unavailable }

class LoadsScreen extends StatefulWidget {
  const LoadsScreen({super.key});

  @override
  State<LoadsScreen> createState() => _LoadsScreenState();
}

class _LoadsScreenState extends State<LoadsScreen> {
  final _searchController = TextEditingController();
  _LoadFilter _filter = _LoadFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<LoadModel> _apply(List<LoadModel> loads) {
    final query = _searchController.text.trim().toLowerCase();
    return loads.where((load) {
      if (query.isNotEmpty && !load.name.toLowerCase().contains(query)) {
        return false;
      }
      switch (_filter) {
        case _LoadFilter.all:
          return true;
        case _LoadFilter.fixed:
          return load.mode == LoadMode.fixed;
        case _LoadFilter.auto:
          return load.mode == LoadMode.auto;
        case _LoadFilter.on:
          return load.displayState == true;
        case _LoadFilter.off:
          return load.displayState != true;
        case _LoadFilter.unavailable:
          return !load.available;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Loads', style: AppTextStyles.title),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Search loads…',
                prefixIcon: Icon(Icons.search, size: 20),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final filter in _LoadFilter.values) ...[
                    ChoiceChip(
                      label: Text(_filterLabel(filter)),
                      selected: _filter == filter,
                      onSelected: (_) => setState(() => _filter = filter),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: ValueListenableBuilder<List<LoadModel>>(
                valueListenable: appState.loads,
                builder: (context, loads, _) {
                  final filtered = _apply(loads);
                  if (filtered.isEmpty) {
                    return const EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'No Loads Match',
                      message: 'Try a different search or filter.',
                    );
                  }
                  return ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final load = filtered[index];
                      return LoadCard(
                        load: load,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => LoadDetailsScreen(load: load),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _filterLabel(_LoadFilter filter) {
    switch (filter) {
      case _LoadFilter.all:
        return 'All';
      case _LoadFilter.fixed:
        return 'Fixed';
      case _LoadFilter.auto:
        return 'Auto';
      case _LoadFilter.on:
        return 'On';
      case _LoadFilter.off:
        return 'Off';
      case _LoadFilter.unavailable:
        return 'Unavailable';
    }
  }
}
