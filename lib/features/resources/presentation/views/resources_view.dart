import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/responsive.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/sac_text_field.dart';
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
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      ref.read(resourceSearchProvider.notifier).state = value;
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    setState(() => _searchController.clear());
    ref.read(resourceSearchProvider.notifier).state = '';
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
    final horizontalPadding = Responsive.horizontalPadding(context);

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
          tooltip: 'common.back'.tr(),
        ),
        title: Text(
          'resources.title'.tr(),
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
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  16,
                  horizontalPadding,
                  0,
                ),
                child: _buildSearchBar(context, c),
              ),
            ),

            // ── Filter chips ────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(horizontalPadding, 14, 0, 0),
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
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
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
                  child: const Center(child: SacLoading()),
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
                      'resources.no_more'.tr(),
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
    return Semantics(
      textField: true,
      label: 'resources.search_hint'.tr(),
      child: SacTextField(
        controller: _searchController,
        hint: 'resources.search_hint'.tr(),
        prefixIcon: HugeIcons.strokeRoundedSearch01,
        onChanged: _onSearchChanged,
        textInputAction: TextInputAction.search,
        suffix: _searchController.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'common.clear'.tr(),
                onPressed: _clearSearch,
                icon: HugeIcon(
                  icon: HugeIcons.strokeRoundedCancelCircle,
                  size: 20,
                  color: c.textTertiary,
                ),
              ),
      ),
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
          child: const Center(child: SacLoading()),
        ),
      );
    }

    if (state.errorMessage != null) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            Responsive.horizontalPadding(context),
            24,
            Responsive.horizontalPadding(context),
            120,
          ),
          child: Center(
            child: SacCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedAlert02,
                    size: 48,
                    color: c.error,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'resources.error_loading'.tr(),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: c.text,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    state.errorMessage!,
                    style: TextStyle(fontSize: 13, color: c.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  SacButton(
                    text: 'common.retry'.tr(),
                    variant: SacButtonVariant.outline,
                    icon: HugeIcons.strokeRoundedRefresh,
                    onPressed: _onRefresh,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (state.items.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 24, 32, 120),
          child: Center(child: _ResourcesEmptyState(colors: c)),
        ),
      );
    }

    return SliverPadding(
      padding: EdgeInsets.symmetric(
          horizontal: Responsive.horizontalPadding(context)),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final resource = state.items[index];
            final animationIndex = index > 6 ? 6 : index;
            return ResourceCard(
              resource: resource,
              animationDelay: Duration(milliseconds: animationIndex * 45),
              onTap: () => _openDetail(context, resource),
            );
          },
          childCount: state.items.length,
        ),
      ),
    );
  }

  String _buildListLabel(String? activeType) {
    if (activeType == null) return 'resources.list_label.all'.tr();
    switch (activeType) {
      case 'document':
        return 'resources.list_label.document'.tr();
      case 'audio':
        return 'resources.list_label.audio'.tr();
      case 'image':
        return 'resources.list_label.image'.tr();
      case 'video_link':
        return 'resources.list_label.video'.tr();
      case 'text':
        return 'resources.list_label.text'.tr();
      default:
        return 'resources.list_label.files'.tr();
    }
  }
}

class _ResourcesEmptyState extends StatelessWidget {
  final SacColors colors;

  const _ResourcesEmptyState({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(AppTheme.radiusXL),
          ),
          child: const Center(
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedFolder02,
              size: 48,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'resources.empty_title'.tr(),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: colors.text,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          'resources.empty_subtitle'.tr(),
          style: TextStyle(fontSize: 14, color: colors.textSecondary),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
