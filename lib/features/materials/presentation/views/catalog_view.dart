import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/fixed_input_icon_slot.dart';
import 'package:sacdia_app/core/widgets/sac_back_button.dart';

import '../providers/cart_provider.dart';
import '../providers/catalog_provider.dart';
import '../providers/categories_provider.dart';
import '../providers/programs_provider.dart';
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

  String? _selectedCat;
  int? _selectedProgramaId;
  String? _searchQ;

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

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: sacAutoBackButton(context),
        backgroundColor: c.background,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'materials.catalog.title'.tr(),
          style: TextStyle(fontWeight: FontWeight.w700, color: c.text),
        ),
        actions: [
          IconButton(
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedInvoice03,
              color: c.text,
              size: 22,
            ),
            tooltip: 'materials.history.title'.tr(),
            onPressed: () => context.push(RouteNames.materialsHistory),
          ),
          Stack(
            alignment: Alignment.topRight,
            children: [
              IconButton(
                icon: HugeIcon(
                  icon: HugeIcons.strokeRoundedShoppingCart01,
                  color: c.text,
                  size: 22,
                ),
                tooltip: 'materials.catalog.cart'.tr(),
                onPressed: () => context.push(RouteNames.materialsCart),
              ),
              if (cartState.itemCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
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
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: TextStyle(color: c.text),
              decoration: InputDecoration(
                hintText: 'materials.catalog.search_hint'.tr(),
                hintStyle: TextStyle(color: c.textTertiary),
                filled: true,
                fillColor: c.surface,
                prefixIconConstraints: FixedInputIconSlot.constraints,
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
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          programasAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (programas) {
              if (programas.isEmpty) return const SizedBox.shrink();
              return SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 0, 28, 0),
                  children: [
                    _FilterChip(
                      label: 'materials.catalog.filter_all'.tr(),
                      selected: _selectedProgramaId == null,
                      onTap: () => setState(() => _selectedProgramaId = null),
                    ),
                    ...programas.map(
                      (p) => _FilterChip(
                        label: p.label,
                        selected: _selectedProgramaId == p.id,
                        onTap: () => setState(() => _selectedProgramaId = p.id),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          categoriasAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (cats) {
              if (cats.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 0, 28, 0),
                    children: [
                      _FilterChip(
                        label: 'materials.catalog.filter_all_categories'.tr(),
                        selected: _selectedCat == null,
                        onTap: () => setState(() => _selectedCat = null),
                      ),
                      ...cats.map(
                        (cat) => _FilterChip(
                          label: cat.label,
                          selected: _selectedCat == cat.slug,
                          onTap: () => setState(() => _selectedCat = cat.slug),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          Expanded(
            child: catalogAsync.when(
              loading: () => const _CatalogSkeleton(),
              error: (error, _) => _ErrorState(
                message: error.toString(),
                onRetry: () => ref.invalidate(catalogProvider(_query)),
              ),
              data: (state) {
                if (state.items.isEmpty && state.errorMessage == null) {
                  return const _EmptyState();
                }
                if (state.items.isEmpty && state.errorMessage != null) {
                  return _ErrorState(
                    message: state.errorMessage!,
                    onRetry: () => ref.invalidate(catalogProvider(_query)),
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: state.items.length + (state.hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == state.items.length) {
                      return _LoadMoreButton(
                        isLoading: state.isLoadingMore,
                        onTap: () => ref
                            .read(catalogProvider(_query).notifier)
                            .loadMore(),
                      );
                    }
                    final item = state.items[index];
                    return ProductCard(
                      item: item,
                      onTap: () => context.push(
                        RouteNames.materialsProductDetailPath(item.id),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_FilterChip> createState() => _FilterChipState();
}

class _FilterChipState extends State<_FilterChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final reduce = SacMotion.reduceMotionOf(context);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: (!reduce && _pressed) ? 0.97 : 1,
          duration: SacMotion.press,
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: widget.selected ? AppColors.primary : c.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: widget.selected ? AppColors.primary : c.border,
              ),
            ),
            child: Text(
              widget.label,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: widget.selected ? Colors.white : c.text,
              ),
            ),
          ),
        ),
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
    final c = context.sac;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedPackage,
            size: 56,
            color: c.textTertiary,
          ),
          const SizedBox(height: 16),
          Text(
            'materials.catalog.empty'.tr(),
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
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
          FilledButton(
            onPressed: onRetry,
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text('common.retry'.tr()),
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
          ? const CircularProgressIndicator(color: AppColors.primary)
          : OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary),
              ),
              child: Text(
                'materials.catalog.load_more'.tr(),
                style: const TextStyle(color: AppColors.primary),
              ),
            ),
    );
  }
}
