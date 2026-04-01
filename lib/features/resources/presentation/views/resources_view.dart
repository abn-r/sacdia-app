import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import '../../domain/entities/resource.dart';
import '../providers/resources_providers.dart';
import '../widgets/resource_card.dart';
import '../widgets/resource_detail_sheet.dart';
import '../widgets/resource_filter_bar.dart';

/// Vista principal de Recursos.
///
/// Reemplaza el placeholder [ResourcesSection] con datos reales desde la API.
///
/// Layout:
/// - AppBar con título "Recursos"
/// - Barra de búsqueda
/// - Filtros de tipo (chips horizontales)
/// - Lista de recursos paginada (carga más al hacer scroll)
/// - Pull-to-refresh
class ResourcesView extends ConsumerStatefulWidget {
  const ResourcesView({super.key});

  @override
  ConsumerState<ResourcesView> createState() => _ResourcesViewState();
}

class _ResourcesViewState extends ConsumerState<ResourcesView> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(resourcesListNotifierProvider.notifier).loadNextPage();
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      ref.read(resourceSearchProvider.notifier).state = value;
    });
  }

  Future<void> _onRefresh() async {
    await ref.read(resourcesListNotifierProvider.notifier).loadFirstPage();
  }

  void _openDetail(BuildContext context, Resource resource) {
    ResourceDetailSheet.show(context, resource);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final activeType = ref.watch(selectedResourceTypeProvider);
    final listState = ref.watch(resourcesListNotifierProvider);

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        foregroundColor: c.text,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        leading: IconButton(
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            color: c.text,
            size: 22,
          ),
          onPressed: () => context.go(RouteNames.homeDashboard),
          tooltip: 'Volver',
        ),
        title: Text(
          'Recursos',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: c.text,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: c.border),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _onRefresh,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── Search bar ─────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: _buildSearchBar(context, c),
              ),
            ),

            // ── Header row ─────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: _buildHeaderRow(context),
              ),
            ),

            // ── Filter chips ────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 0, 0),
                child: ResourceFilterBar(
                  activeType: activeType,
                  onTypeChanged: (type) {
                    ref.read(selectedResourceTypeProvider.notifier).state =
                        type;
                  },
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 18)),

            // ── List label ─────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  _buildListLabel(activeType),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: c.textSecondary,
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 10)),

            // ── Resource list ──────────────────────────────────────
            _buildResourceList(context, listState),

            // ── Load more indicator ────────────────────────────────
            if (listState.isLoadingMore)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: LoadingAnimationWidget.stretchedDots(
                      color: AppColors.primary,
                      size: 36,
                    ),
                  ),
                ),
              ),

            // ── End of list label ──────────────────────────────────
            if (!listState.isLoading &&
                !listState.isLoadingMore &&
                !listState.hasMore &&
                listState.items.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'No hay más recursos',
                      style: TextStyle(
                        fontSize: 13,
                        color: c.textTertiary,
                      ),
                    ),
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, SacColors c) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(color: c.border, width: 1),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          HugeIcon(
            icon: HugeIcons.strokeRoundedSearch01,
            size: 18,
            color: c.textTertiary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: TextStyle(fontSize: 14, color: c.text),
              decoration: InputDecoration(
                hintText: 'Buscar recursos...',
                hintStyle:
                    TextStyle(fontSize: 14, color: c.textTertiary),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (_searchController.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchController.clear();
                ref.read(resourceSearchProvider.notifier).state = '';
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedCancelCircle,
                  size: 18,
                  color: c.textTertiary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeaderRow(BuildContext context) {
    final c = context.sac;
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primarySurface,
            borderRadius: BorderRadius.circular(AppTheme.radiusSM),
          ),
          child: const Center(
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedFolder02,
              size: 20,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'Todos los recursos',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: c.text,
              ),
        ),
      ],
    );
  }

  Widget _buildResourceList(
    BuildContext context,
    ResourcesListState state,
  ) {
    final c = context.sac;

    if (state.isLoading) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Center(
            child: LoadingAnimationWidget.stretchedDots(
              color: AppColors.primary,
              size: 40,
            ),
          ),
        ),
      );
    }

    if (state.errorMessage != null) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedAlert02,
                size: 48,
                color: c.textTertiary,
              ),
              const SizedBox(height: 12),
              Text(
                'Error al cargar recursos',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: c.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                state.errorMessage!,
                style: TextStyle(fontSize: 13, color: c.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _onRefresh,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (state.items.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedFolder02,
                size: 56,
                color: c.textTertiary,
              ),
              const SizedBox(height: 12),
              Text(
                'No hay recursos disponibles',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: c.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Prueba con otro filtro o búsqueda',
                style: TextStyle(fontSize: 13, color: c.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final resource = state.items[index];
            return ResourceCard(
              resource: resource,
              onTap: () => _openDetail(context, resource),
            );
          },
          childCount: state.items.length,
        ),
      ),
    );
  }

  String _buildListLabel(String? activeType) {
    if (activeType == null) return 'Todos los archivos';
    switch (activeType) {
      case 'document':
        return 'Documentos';
      case 'audio':
        return 'Archivos de audio';
      case 'image':
        return 'Imágenes';
      case 'video_link':
        return 'Videos';
      case 'text':
        return 'Contenido de texto';
      default:
        return 'Archivos';
    }
  }
}
