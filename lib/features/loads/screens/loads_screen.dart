import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/responsive_content.dart';
import '../../../core/widgets/section_card.dart';
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
          return load.displayState != true && load.available;
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
      child: ValueListenableBuilder<List<LoadModel>>(
        valueListenable: appState.loads,
        builder: (context, loads, _) {
          final filtered = _apply(loads);
          final onCount = loads.where((load) => load.displayState == true).length;
          final autoCount = loads.where((load) => load.mode == LoadMode.auto).length;

          return SingleChildScrollView(
            child: ResponsiveContent(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PageHeader(
                    title: 'Loads',
                    subtitle:
                        '${loads.length} configured · $onCount on · $autoCount automatic',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SectionCard(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final horizontal = constraints.maxWidth >= 760;
                        final search = SizedBox(
                          width: horizontal ? 360 : double.infinity,
                          child: TextField(
                            controller: _searchController,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              hintText: 'Search loads or nodes',
                              prefixIcon: const Icon(Icons.search_rounded, size: 20),
                              suffixIcon: _searchController.text.isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: 'Clear search',
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() {});
                                      },
                                      icon: const Icon(Icons.close_rounded, size: 19),
                                    ),
                            ),
                          ),
                        );

                        final filters = Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xs,
                          children: [
                            for (final filter in _LoadFilter.values)
                              ChoiceChip(
                                label: Text(_filterLabel(filter)),
                                selected: _filter == filter,
                                onSelected: (_) => setState(() => _filter = filter),
                              ),
                          ],
                        );

                        if (!horizontal) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              search,
                              const SizedBox(height: AppSpacing.sm),
                              filters,
                            ],
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            search,
                            const SizedBox(width: AppSpacing.md),
                            Expanded(child: filters),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (filtered.isEmpty)
                    EmptyState(
                      icon: loads.isEmpty
                          ? Icons.electrical_services_outlined
                          : Icons.search_off_rounded,
                      title: loads.isEmpty
                          ? 'No loads configured'
                          : 'No loads match these filters',
                      message: loads.isEmpty
                          ? 'Loads will appear here after they are configured on Central or a Smart Node.'
                          : 'Change the search term or select a different filter.',
                    )
                  else
                    ResponsiveCardGrid(
                      minCardWidth: 320,
                      maxColumns: 3,
                      children: [
                        for (final load in filtered)
                          LoadCard(load: load, onTap: () => _openLoad(load)),
                      ],
                    ),
                  if (filtered.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Showing ${filtered.length} of ${loads.length} loads',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textTertiary,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
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
