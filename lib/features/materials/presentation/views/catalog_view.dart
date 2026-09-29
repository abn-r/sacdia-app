import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/fixed_input_icon_slot.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_empty_state.dart';
import 'package:sacdia_app/core/widgets/sac_filter_chip.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';

import '../providers/cart_provider.dart';
import '../providers/catalog_provider.dart';
import '../providers/categories_provider.dart';
import '../providers/programs_provider.dart';
import '../widgets/materials_program_field.dart';
import '../widgets/product_card.dart';

/// Pantalla principal del catálogo de materiales.
class CatalogView extends ConsumerStatefulWidget {
  const CatalogView({super.key});

  @override
  ConsumerState<CatalogView> createState() => _CatalogViewState();
}

class _CatalogViewState extends ConsumerState<CatalogView> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  /// UUID de categoría para `GET /materials/catalog?cat=`. El API exige UUID,
  /// no el slug (`insignias`, `uniforme`, …); un slug responde 400.
  String? _selectedCat;
  int? _selectedProgramaId;
  String? _searchQ;
  CatalogState? _lastCatalog;

  CatalogQuery get _query => CatalogQuery(
        cat: _selectedCat,
        programaId: _selectedProgramaId,
        q: _searchQ,
      );

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() => _searchQ = value.isEmpty ? null : value);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final cartState = ref.watch(cartProvider);
    final catalogAsync = ref.watch(catalogProvider(_query));
    final categoriasAsync = ref.watch(categoriesProvider);
    final programasAsync = ref.watch(programsProvider);

    ref.listen<AsyncValue<CatalogState>>(catalogProvider(_query), (_, next) {
      final data = next.valueOrNull;
      if (data != null) {
        _lastCatalog = data;
      }
    });

    return Scaffold(
      backgroundColor: c.background,
      appBar: SacTopBar(
        title: 'materials.catalog.title'.tr(),
        actions: [
          SacPressable(
            listenOnly: true,
            child: IconButton(
              enableFeedback: false,
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedInvoice03,
                color: c.text,
                size: 22,
              ),
              tooltip: 'materials.history.title'.tr(),
              onPressed: () => context.push(RouteNames.materialsHistory),
            ),
          ),
          Stack(
            alignment: Alignment.topRight,
            children: [
              SacPressable(
                listenOnly: true,
                child: IconButton(
                  enableFeedback: false,
                  icon: HugeIcon(
                    icon: HugeIcons.strokeRoundedShoppingCart01,
                    color: c.text,
                    size: 22,
                  ),
                  tooltip: 'materials.catalog.cart'.tr(),
                  onPressed: () => context.push(RouteNames.materialsCart),
                ),
              ),
              if (cartState.itemCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: SacAccent.of(context).color,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${cartState.itemCount > 9 ? '9+' : cartState.itemCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                style: TextStyle(color: c.text, fontSize: 15, height: 1.2),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'materials.catalog.search_hint'.tr(),
                  hintStyle: TextStyle(
                    color: c.textSecondary,
                    fontSize: 15,
                    height: 1.2,
                  ),
                  filled: true,
                  fillColor: c.surface,
                  prefixIconConstraints:
                      const BoxConstraints.tightFor(width: 44, height: 44),
                  prefixIcon: FixedInputIconSlot(
                    icon: HugeIcons.strokeRoundedSearch01,
                    color: c.textSecondary,
                    iconSize: 20,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: c.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: c.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: SacAccent.of(context).color),
                  ),
                  contentPadding: const EdgeInsets.fromLTRB(4, 10, 14, 10),
                ),
              ),
            ),
          ),
          programasAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (programas) {
              if (programas.isEmpty) return const SizedBox.shrink();
              return MaterialsProgramField(
                programs: programas,
                selectedId: _selectedProgramaId,
                onSelected: (id) => setState(() => _selectedProgramaId = id),
              );
            },
          ),
          categoriasAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (cats) {
              if (cats.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                      child: Semantics(
                        header: true,
                        child: Text(
                          'materials.catalog.filter_category_label'.tr(),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: c.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: SacFilterChip.barHeight,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(16, 0, 28, 0),
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: SacFilterChip(
                              label: 'materials.catalog.filter_all_categories'
                                  .tr(),
                              variant: SacFilterChipVariant.quiet,
                              selected: _selectedCat == null,
                              onTap: () => setState(() => _selectedCat = null),
                            ),
                          ),
                          ...cats.map(
                            (cat) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: SacFilterChip(
                                label: cat.label,
                                variant: SacFilterChipVariant.quiet,
                                selected: _selectedCat == cat.id,
                                onTap: () =>
                                    setState(() => _selectedCat = cat.id),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          Expanded(child: _buildCatalogResults(catalogAsync)),
        ],
      ),
    );
  }

  Widget _buildCatalogResults(AsyncValue<CatalogState> catalogAsync) {
    final fresh = catalogAsync.valueOrNull;
    final displayed = fresh ?? (catalogAsync.isLoading ? _lastCatalog : null);

    if (catalogAsync.hasError && fresh == null && !catalogAsync.isLoading) {
      return _ErrorState(
        message: catalogAsync.error.toString(),
        onRetry: () => ref.invalidate(catalogProvider(_query)),
      );
    }

    if (displayed == null) {
      return const _CatalogSkeleton();
    }

    if (displayed.items.isEmpty && displayed.errorMessage == null) {
      return const _EmptyState();
    }
    if (displayed.items.isEmpty && displayed.errorMessage != null) {
      return _ErrorState(
        message: displayed.errorMessage!,
        onRetry: () => ref.invalidate(catalogProvider(_query)),
      );
    }

    return AnimatedSwitcher(
      duration: SacMotion.reducedFade,
      switchInCurve: SacMotion.easeOut,
      switchOutCurve: SacMotion.easeOut,
      transitionBuilder: (child, animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: GridView.builder(
        key: ValueKey(displayed.items.map((item) => item.id).join(',')),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.72,
        ),
        itemCount: displayed.items.length + (displayed.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == displayed.items.length) {
            return _LoadMoreButton(
              isLoading: displayed.isLoadingMore,
              onTap: () =>
                  ref.read(catalogProvider(_query).notifier).loadMore(),
            );
          }
          final item = displayed.items[index];
          return ProductCard(
            item: item,
            onTap: () => context.push(
              RouteNames.materialsProductDetailPath(item.id),
            ),
          );
        },
      ),
    );
  }
}

class _CatalogSkeleton extends StatelessWidget {
  const _CatalogSkeleton();

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.72,
      ),
      itemCount: 4,
      itemBuilder: (_, __) => Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border.withValues(alpha: 0.7)),
        ),
        child: Column(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: c.border.withValues(alpha: 0.35),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 12,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: c.border.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 12,
                    width: 72,
                    decoration: BoxDecoration(
                      color: c.border.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return SacEmptyState(
      icon: HugeIcons.strokeRoundedPackage,
      title: 'materials.catalog.empty'.tr(),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const HugeIcon(
            icon: HugeIcons.strokeRoundedAlert02,
            size: 48,
            color: AppColors.error,
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textSecondary),
            ),
          ),
          const SizedBox(height: 16),
          SacButton(
            text: 'common.retry'.tr(),
            variant: SacButtonVariant.primary,
            fullWidth: false,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

class _LoadMoreButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onTap;

  const _LoadMoreButton({required this.isLoading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: isLoading
          ? CircularProgressIndicator(color: SacAccent.of(context).color)
          : SacButton(
              text: 'materials.catalog.load_more'.tr(),
              variant: SacButtonVariant.outline,
              fullWidth: false,
              onPressed: onTap,
            ),
    );
  }
}
