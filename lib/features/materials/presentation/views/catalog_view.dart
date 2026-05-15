import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/config/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/cart_provider.dart';
import '../providers/catalog_provider.dart';
import '../providers/categories_provider.dart';
import '../providers/programs_provider.dart';
import '../widgets/product_card.dart';

/// Pantalla principal del catálogo de materiales.
///
/// Muestra un grid 2×N de productos con filtros de búsqueda, programa y
/// categoría. Soporta paginación incremental mediante "Cargar más".
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
    final cartState = ref.watch(cartProvider);
    final catalogAsync = ref.watch(catalogProvider(_query));
    final categoriasAsync = ref.watch(categoriesProvider);
    final programasAsync = ref.watch(programsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Materiales'),
        actions: [
          IconButton(
            icon: const HugeIcon(icon: HugeIcons.strokeRoundedInvoice03),
            tooltip: 'Mis pedidos',
            onPressed: () => context.push(RouteNames.materialsHistory),
          ),
          Stack(
            alignment: Alignment.topRight,
            children: [
              IconButton(
                icon:
                    const HugeIcon(icon: HugeIcons.strokeRoundedShoppingCart01),
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
          // ── Search ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Buscar productos...',
                prefixIcon:
                    const HugeIcon(icon: HugeIcons.strokeRoundedSearch01),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.lightBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.lightBorder),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),

          // ── Program filter ──
          programasAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (programas) {
              if (programas.isEmpty) return const SizedBox.shrink();
              return SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _FilterChip(
                      label: 'Todos',
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

          // ── Category chips ──
          categoriasAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (cats) {
              if (cats.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _FilterChip(
                        label: 'Categorías',
                        selected: _selectedCat == null,
                        onTap: () => setState(() => _selectedCat = null),
                      ),
                      ...cats.map(
                        (c) => _FilterChip(
                          label: c.label,
                          selected: _selectedCat == c.slug,
                          onTap: () => setState(() => _selectedCat = c.slug),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 8),

          // ── Product grid ──
          Expanded(
            child: catalogAsync.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(
                color: AppColors.primary,
              )),
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
                    childAspectRatio: 0.75,
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

// ── Sub-widgets ────────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.lightBorder,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: selected ? Colors.white : AppColors.lightText,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          HugeIcon(
              icon: HugeIcons.strokeRoundedPackage,
              size: 56,
              color: AppColors.lightTextTertiary),
          SizedBox(height: 16),
          Text(
            'No hay productos disponibles',
            style: TextStyle(
              color: AppColors.lightTextSecondary,
              fontSize: 16,
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const HugeIcon(
              icon: HugeIcons.strokeRoundedAlert02,
              size: 48,
              color: AppColors.error),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.lightTextSecondary),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onRetry,
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Reintentar'),
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
              child: const Text(
                'Cargar más',
                style: TextStyle(color: AppColors.primary),
              ),
            ),
    );
  }
}
