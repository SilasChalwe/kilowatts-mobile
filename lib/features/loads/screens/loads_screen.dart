import 'package:flutter/material.dart';

import '../../../core/app_state/app_state_scope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/responsive_content.dart';
import '../../../core/widgets/section_card.dart';
import '../models/load_model.dart';
import '../widgets/load_card.dart';
import 'load_details_screen.dart';

class LoadsScreen extends StatefulWidget {
  const LoadsScreen({super.key});

  @override
  State<LoadsScreen> createState() => _LoadsScreenState();
}

class _LoadsScreenState extends State<LoadsScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<LoadModel> _apply(List<LoadModel> loads) {
    final terms = _searchController.text
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty)
        .toList();
    return loads.where((load) {
      if (terms.isEmpty) return true;
      final searchable = [
        load.name,
        load.owningNodeName ?? '',
        load.owningNodeMac,
        load.mode == LoadMode.fixed ? 'fixed' : 'auto automatic',
        load.displayState == true ? 'on' : 'off',
        load.available ? 'available' : 'unavailable',
      ].join(' ').toLowerCase();
      return terms.every(searchable.contains);
    }).toList();
  }

  void _openLoad(LoadModel load) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => LoadDetailsScreen(load: load)));
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);

    return SafeArea(
      child: AnimatedBuilder(
        animation: Listenable.merge([
          appState.loads,
          appState.connectionStatus,
          appState.centralAvailability,
          appState.lastLiveSystemUpdate,
        ]),
        builder: (context, _) {
          final isLive = appState.isSystemStateLive;
          final loads = isLive ? appState.loads.value : const <LoadModel>[];
          final filtered = _apply(loads);

          return SingleChildScrollView(
            child: ResponsiveContent(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionCard(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search loads or nodes',
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          size: 20,
                        ),
                        suffixIcon: _searchController.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear search',
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {});
                                },
                                icon: const Icon(
                                  Icons.close_rounded,
                                  size: 19,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (filtered.isEmpty)
                    EmptyState(
                      icon: !isLive
                          ? Icons.cloud_off_outlined
                          : loads.isEmpty
                          ? Icons.electrical_services_outlined
                          : Icons.search_off_rounded,
                      title: !isLive
                          ? 'Not connected to Central'
                          : loads.isEmpty
                          ? 'No loads configured'
                          : 'No loads match these filters',
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
                      '${filtered.length} of ${loads.length} loads',
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
}
