import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';

import '../../domain/entities/honor.dart';
import '../theme/honor_category_palette.dart';
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

          // ── Catalog filters ──────────────────────────────────────
          // Scope is a primary mode switch; categories are a secondary filter
          // and live inside the same panel to avoid duplicated chip rows.
          Consumer(
            builder: (context, ref, child) {
              final activeScope =
                  ref.watch(activeHonorCatalogScopeProvider).valueOrNull;
              final manualScope = ref.watch(selectedHonorCatalogScopeProvider);
              final HonorCatalogScope selectedScope =
                  activeScope ?? manualScope;
              final isScopeLocked = activeScope != null;
              final selectedCategory = ref.watch(selectedCategoryProvider);

              if (selectedScope == HonorCatalogScope.adventurers) {
                return _buildCatalogFilters(
                  context,
                  selectedScope: selectedScope,
                  isScopeLocked: isScopeLocked,
                  selectedCategory: selectedCategory,
                );
              }

              final categoriesAsync = ref.watch(honorCategoriesProvider);
              return categoriesAsync.when(
                data: (categories) => _buildCatalogFilters(
                  context,
                  selectedScope: selectedScope,
                  isScopeLocked: isScopeLocked,
                  categories: categories,
                  selectedCategory: selectedCategory,
                ),
                loading: () => _buildCatalogFilters(
                  context,
                  selectedScope: selectedScope,
                  isScopeLocked: isScopeLocked,
                  selectedCategory: selectedCategory,
                  isCategoryLoading: true,
                ),
                error: (_, __) => _buildCatalogFilters(
                  context,
                  selectedScope: selectedScope,
                  selectedCategory: selectedCategory,
                ),
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

  Widget _buildCatalogFilters(
    BuildContext context, {
    required HonorCatalogScope selectedScope,
    List<dynamic>? categories,
    int? selectedCategory,
    bool isCategoryLoading = false,
    bool isScopeLocked = false,
  }) {
    final showCategories = selectedScope != HonorCatalogScope.adventurers;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: context.sac.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: context.sac.borderLight),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: Text(
                'honors.catalog.catalog_filter_label'.tr(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                  color: context.sac.textSecondary,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _buildScopeSegmentedControl(
                context,
                selectedScope,
                isScopeLocked: isScopeLocked,
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: showCategories
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Divider(
                                  height: 1,
                                  color: context.sac.borderLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 2, 14, 8),
                          child: Text(
                            'honors.catalog.category_filter_label'.tr(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: context.sac.textTertiary,
                            ),
                          ),
                        ),
                        if (isCategoryLoading)
                          const SizedBox(height: 52)
                        else
                          _buildCategoryChips(
                            categories ?? const [],
                            selectedCategory,
                          ),
                      ],
                    )
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                      child: Text(
                        'honors.catalog.adventurers_filter_hint'.tr(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: context.sac.textSecondary,
                          height: 1.25,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScopeSegmentedControl(
    BuildContext context,
    HonorCatalogScope selectedScope, {
    bool isScopeLocked = false,
  }) {
    final allScopes = <({HonorCatalogScope value, String label, Color color})>[
      (
        value: HonorCatalogScope.all,
        label: 'honors.catalog.scope_all'.tr(),
        color: AppColors.error,
      ),
      (
        value: HonorCatalogScope.adventurers,
        label: 'honors.catalog.scope_adventurers'.tr(),
        color: AppColors.info,
      ),
      (
        value: HonorCatalogScope.pathfindersAndMasterGuides,
        label: 'honors.catalog.scope_pathfinders_gm'.tr(),
        color: AppColors.secondaryDark,
      ),
    ];
    final scopes = isScopeLocked
        ? allScopes.where((scope) => scope.value == selectedScope).toList()
        : allScopes;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.sac.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: scopes.map((scope) {
          final isSelected = selectedScope == scope.value;
          return Expanded(
            child: Semantics(
              button: true,
              selected: isSelected,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(13),
                    onTap: isScopeLocked
                        ? null
                        : () {
                            ref
                                .read(
                                    selectedHonorCatalogScopeProvider.notifier)
                                .state = scope.value;
                            ref.read(selectedCategoryProvider.notifier).state =
                                null;
                          },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      constraints: const BoxConstraints(minHeight: 44),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? context.sac.surface
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(13),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: scope.color.withValues(alpha: 0.16),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: isSelected ? 7 : 0,
                            height: isSelected ? 7 : 0,
                            margin: EdgeInsets.only(right: isSelected ? 6 : 0),
                            decoration: BoxDecoration(
                              color: scope.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Flexible(
                            child: Text(
                              scope.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: isSelected
                                    ? context.sac.text
                                    : context.sac.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
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
                      'honors.catalog.title'.tr(),
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.error),
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
                        color: context.sac.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.sac.borderLight),
                      ),
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '$completed',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: context.sac.text,
                              ),
                            ),
                            TextSpan(
                              text: '/$total',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: context.sac.textSecondary,
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
                style: TextStyle(color: context.sac.text, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'honors.catalog.search_hint'.tr(),
                  hintStyle: TextStyle(
                    color: context.sac.textTertiary,
                    fontSize: 14,
                  ),
                  prefixIcon: HugeIcon(
                    icon: HugeIcons.strokeRoundedSearch01,
                    color: context.sac.textSecondary,
                    size: 20,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: HugeIcon(
                            icon: HugeIcons.strokeRoundedCancel01,
                            color: context.sac.textSecondary,
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
                  fillColor: context.sac.surfaceVariant,
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
                label: 'honors.catalog.all_category'.tr(),
                isSelected: selectedCategory == null,
                activeColor: AppColors.error,
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
              activeBorderColor: getCategoryAccentColor(
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
              color: context.sac.textTertiary,
            ),
            const SizedBox(height: 12),
            Text(
              'honors.catalog.empty'.tr(),
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
      color: AppColors.primary,
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
            color: AppColors.error,
          ),
          const SizedBox(height: 16),
          Text(
            'honors.catalog.error_load'.tr(),
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
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedRefresh,
              size: 18,
              color: Colors.white,
            ),
            label: Text('honors.catalog.retry'.tr()),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
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
