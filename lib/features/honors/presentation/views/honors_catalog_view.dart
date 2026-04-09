import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';

import '../../domain/entities/honor.dart';
import '../../domain/utils/honor_category_colors.dart';
import '../../domain/entities/user_honor.dart';
import '../providers/honors_providers.dart';
import '../widgets/honor_card.dart';
import '../widgets/honor_category_chip.dart';

// ── HonorCard with progress ───────────────────────────────────────────────────

/// Wraps [HonorCard] and injects progress stats for enrolled honors.
///
/// For non-enrolled honors, renders [HonorCard] directly with no progress data.
/// For enrolled honors, reads [honorProgressStatsProvider] (derived from
/// [userHonorProgressProvider]) and passes the stats to [HonorCard].
/// The provider is keepAlive so stats persist across tab switches.
class _HonorCardWithProgress extends ConsumerWidget {
  final Honor honor;
  final UserHonor? userHonor;

  const _HonorCardWithProgress({
    required this.honor,
    required this.userHonor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (userHonor == null) {
      return HonorCard(
        honor: honor,
        userHonor: null,
        onTap: () => context.push(
          RouteNames.honorDetailPath(honor.id.toString()),
          extra: honor,
        ),
      );
    }

    // Enrolled: read progress stats derived from the progress provider.
    // This is a synchronous derivation — no loading state.
    final stats = ref.watch(honorProgressStatsProvider(honor.id));

    return HonorCard(
      honor: honor,
      userHonor: userHonor,
      progressPercentage: stats.total > 0 ? stats.percentage : null,
      completedCount: stats.total > 0 ? stats.completed : null,
      totalRequirements: stats.total > 0 ? stats.total : null,
      onTap: () => context.push(
        RouteNames.honorDetailPath(honor.id.toString()),
        extra: honor,
      ),
    );
  }
}

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
    return Scaffold(
      backgroundColor: context.sac.background,
      body: Column(
        children: [
          // ── Dark header ──────────────────────────────────────────
          // Only rebuilds when userHonorStatsLocalProvider changes (user
          // honor list fetched/updated), NOT on search or category changes.
          Consumer(
            builder: (context, ref, child) {
              final statsAsync = ref.watch(userHonorStatsLocalProvider);
              return _buildHeader(context, statsAsync);
            },
          ),

          // ── Category chips ───────────────────────────────────────
          // Only rebuilds when categories are fetched or the selected
          // category changes, NOT on search query changes.
          Consumer(
            builder: (context, ref, child) {
              final categoriesAsync = ref.watch(honorCategoriesProvider);
              final selectedCategory = ref.watch(selectedCategoryProvider);
              return categoriesAsync.when(
                data: (categories) => _buildCategoryChips(
                  categories,
                  selectedCategory,
                ),
                loading: () => const SizedBox(height: 52),
                error: (_, __) => const SizedBox(height: 52),
              );
            },
          ),

          // ── Honor cards list ─────────────────────────────────────
          // Only this section rebuilds on every search keystroke.
          Expanded(
            child: Consumer(
              builder: (context, ref, child) {
                final honorsWithStatus = ref.watch(honorsWithStatusProvider);
                return honorsWithStatus.when(
                  data: (items) => _buildHonorsList(items),
                  loading: () => const Center(child: SacLoading()),
                  error: (error, _) => _buildErrorState(context),
                );
              },
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
      color: context.sac.surface,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title row
              Row(
                children: [
                  // Back button
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedArrowLeft01,
                        color: context.sac.text,
                        size: 22,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Especialidades',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.sacRed),
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
                                color: Colors.white,
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
                activeColor: AppColors.sacRed,
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
              activeColor: getCategoryColor(
                categoryId: category.id,
                categoryName: category.name,
              ),
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
            Text(
              'No hay especialidades en esta categoria',
              style: TextStyle(
                fontSize: 16,
                color: context.sac.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.sacBlue,
      onRefresh: () async {
        ref.invalidate(honorsGroupedByCategoryProvider);
        ref.invalidate(allHonorsProvider);
        ref.invalidate(userHonorsProvider);
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return _HonorCardWithProgress(
            honor: item.honor,
            userHonor: item.userHonor,
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
          Text(
            'Error al cargar especialidades',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: context.sac.text,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              ref.invalidate(honorsGroupedByCategoryProvider);
              ref.invalidate(allHonorsProvider);
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
