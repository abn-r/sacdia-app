import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';

import '../../domain/entities/honor.dart';
import '../../domain/entities/user_honor.dart';
import '../providers/honors_providers.dart';
import '../widgets/honor_card.dart';
import '../widgets/honor_category_chip.dart';

/// Redesigned honors catalog view.
///
/// Layout:
/// - Dark header (#183651) with title + completed/total badge + search bar
/// - Horizontal category chips row ("Todas" default)
/// - Vertical list of HonorCard (border-left state indicators)
class HonorsCatalogView extends ConsumerStatefulWidget {
  const HonorsCatalogView({super.key});

  @override
  ConsumerState<HonorsCatalogView> createState() => _HonorsCatalogViewState();
}

class _HonorsCatalogViewState extends ConsumerState<HonorsCatalogView> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(searchQueryProvider.notifier).state = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(honorCategoriesProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final honorsWithStatus = ref.watch(honorsWithStatusProvider);
    final statsAsync = ref.watch(userHonorStatsProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // ── Dark header ──────────────────────────────────────────
          _buildHeader(context, statsAsync),

          // ── Category chips ───────────────────────────────────────
          categoriesAsync.when(
            data: (categories) => _buildCategoryChips(
              categories,
              selectedCategory,
            ),
            loading: () => const SizedBox(height: 52),
            error: (_, __) => const SizedBox(height: 52),
          ),

          // ── Honor cards list ─────────────────────────────────────
          Expanded(
            child: honorsWithStatus.when(
              data: (items) => _buildHonorsList(items),
              loading: () => const Center(child: SacLoading()),
              error: (error, _) => _buildErrorState(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    AsyncValue<Map<String, dynamic>> statsAsync,
  ) {
    final completed = statsAsync.maybeWhen(
      data: (s) => s['validated'] as int? ?? 0,
      orElse: () => 0,
    );
    final total = statsAsync.maybeWhen(
      data: (s) => s['total'] as int? ?? 0,
      orElse: () => 0,
    );

    return Container(
      color: AppColors.sacBlack,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Especialidades',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  // Completed/total badge pill
                  if (total > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(20),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '$completed',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.sacGreen,
                              ),
                            ),
                            TextSpan(
                              text: '/$total',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withAlpha(180),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Search bar
              TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Buscar especialidad...',
                  hintStyle: TextStyle(
                    color: Colors.white.withAlpha(120),
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: Colors.white.withAlpha(120),
                    size: 20,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            color: Colors.white.withAlpha(120),
                            size: 18,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            ref.read(searchQueryProvider.notifier).state = '';
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white.withAlpha(20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChips(
    List<dynamic> categories,
    int? selectedCategory,
  ) {
    return SizedBox(
      height: 52,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: categories.length + 1, // +1 for "Todas"
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: HonorCategoryChip(
                label: 'Todas',
                isSelected: selectedCategory == null,
                onTap: () {
                  ref.read(selectedCategoryProvider.notifier).state = null;
                },
              ),
            );
          }

          final category = categories[index - 1];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: HonorCategoryChip(
              label: category.name,
              isSelected: selectedCategory == category.id,
              onTap: () {
                final current = ref.read(selectedCategoryProvider);
                ref.read(selectedCategoryProvider.notifier).state =
                    current == category.id ? null : category.id;
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildHonorsList(
    List<({Honor honor, UserHonor? userHonor})> items,
  ) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedAward01,
              size: 56,
              color: AppColors.sacGrey,
            ),
            const SizedBox(height: 12),
            const Text(
              'No hay especialidades en esta categoria',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.sacBlue,
      onRefresh: () async {
        ref.invalidate(filteredHonorsProvider);
        ref.invalidate(userHonorsProvider);
        ref.invalidate(userHonorStatsProvider);
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return HonorCard(
            honor: item.honor,
            userHonor: item.userHonor,
            onTap: () {
              if (item.userHonor != null) {
                // TODO(honors): navigate to evidence view once
                // RouteNames.honorEvidencePath is added to route_names.dart
                // and the route is registered in the router.
                // For now, fall back to detail view.
                context.push(
                  RouteNames.honorDetailPath(item.honor.id.toString()),
                );
              } else {
                context.push(
                  RouteNames.honorDetailPath(item.honor.id.toString()),
                );
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedAlert02,
            size: 56,
            color: AppColors.sacRed,
          ),
          const SizedBox(height: 16),
          const Text(
            'Error al cargar especialidades',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              ref.invalidate(filteredHonorsProvider);
              ref.invalidate(userHonorsProvider);
            },
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Reintentar'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.sacBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
