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
      if (query.isNotEmpty) {
        final searchable = [
          load.name,
          load.owningNodeName ?? '',
          load.owningNodeMac,
        ].join(' ').toLowerCase();
        if (!searchable.contains(query)) return false;
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

  void _openLoad(LoadModel load) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LoadDetailsScreen(load: load)),
    );
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
            ValueListenableBuilder<List<LoadModel>>(
              valueListenable: appState.loads,
              builder: (context, loads, _) {
                final onCount = loads.where((load) => load.displayState == true).length;
                return Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Loads', style: AppTextStyles.title),
                          const SizedBox(height: 2),
                          Text(
                            '${loads.length} configured · $onCount currently on',
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search load, node or MAC address…',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close_rounded, size: 20),
                      ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 38,
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
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: ValueListenableBuilder<List<LoadModel>>(
                valueListenable: appState.loads,
                builder: (context, loads, _) {
                  final filtered = _apply(loads);
                  if (filtered.isEmpty) {
                    return EmptyState(
                      icon: Icons.search_off_rounded,
                      title: loads.isEmpty ? 'No loads configured' : 'No loads match',
                      message: loads.isEmpty
                          ? 'Configured loads will appear here after installation.'
                          : 'Try a different search term or filter.',
                    );
                  }

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 1150
                          ? 3
                          : constraints.maxWidth >= 720
                              ? 2
                              : 1;

                      if (columns == 1) {
                        return ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (context, index) {
                            final load = filtered[index];
                            return LoadCard(load: load, onTap: () => _openLoad(load));
                          },
                        );
                      }

                      return GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: AppSpacing.sm,
                          mainAxisSpacing: AppSpacing.sm,
                          childAspectRatio: 1.55,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final load = filtered[index];
                          return LoadCard(load: load, onTap: () => _openLoad(load));
                        },
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
        return 'Automatic';
      case _LoadFilter.on:
        return 'On';
      case _LoadFilter.off:
        return 'Off';
      case _LoadFilter.unavailable:
        return 'Unavailable';
    }
  }
}
