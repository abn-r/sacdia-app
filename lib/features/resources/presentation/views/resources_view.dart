import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/animations/staggered_list_animation.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/responsive.dart';
import 'package:sacdia_app/core/errors/user_error_message.dart';
import 'package:sacdia_app/core/widgets/sac_empty_state.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/sac_text_field.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
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
/// - Grilla de recursos paginada (carga más al hacer scroll)
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
      extendBodyBehindAppBar: true,
      backgroundColor: c.background,
      appBar: SacTopBar(
          title: 'resources.title'.tr(),
          onBack: () => context.go(RouteNames.homeDashboard),
          frosted: true),
      body: SacFrostedVeil(
        child: Builder(
          builder: (context) => RefreshIndicator(
            color: SacAccent.of(context).color,
            onRefresh: _onRefresh,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                    child: SizedBox(height: SacTopBar.frostedInset(context))),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      12,
                      horizontalPadding,
                      0,
                    ),
                    child: _buildSearchBar(context, c),
                  ),
                ),
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
                if (_searchController.text.trim().isNotEmpty) ...[
                  const SliverToBoxAdapter(child: SizedBox(height: 14)),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: horizontalPadding),
                      child: Text(
                        'resources.list_label.search'.tr(),
                        style: TextStyle(
                          fontSize: SacFontSize.bodyMedium,
                          fontWeight: FontWeight.w700,
                          color: c.textTertiary,
                        ),
                      ),
                    ),
                  ),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
                _buildResourceList(context, listState),
                if (listState.isLoadingMore)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: SacLoading()),
                    ),
                  ),
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
                            fontSize: SacFontSize.bodyMedium,
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
            : SacPressable(
                listenOnly: true,
                child: IconButton(
                  enableFeedback: false,
                  tooltip: 'common.clear'.tr(),
                  onPressed: _clearSearch,
                  icon: HugeIcon(
                    icon: HugeIcons.strokeRoundedCancelCircle,
                    size: 20,
                    color: c.textTertiary,
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildResourceList(
    BuildContext context,
    ResourcesListState state,
  ) {
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
        child: SacErrorState(
          title: 'resources.error_loading'.tr(),
          message: userErrorMessage(state.errorMessage),
          onRetry: _onRefresh,
          padding: EdgeInsets.fromLTRB(
            Responsive.horizontalPadding(context),
            24,
            Responsive.horizontalPadding(context),
            120,
          ),
        ),
      );
    }

    if (state.items.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 120),
          child: SacEmptyState(
            icon: HugeIcons.strokeRoundedFolder02,
            title: 'resources.empty_title'.tr(),
            body: 'resources.empty_subtitle'.tr(),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: EdgeInsets.symmetric(
          horizontal: Responsive.horizontalPadding(context)),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 200,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.72,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final resource = state.items[index];
            return StaggeredListItem(
              index: index,
              staggerDelay: SacMotion.stagger,
              duration: SacMotion.standard,
              slideOffset: 8,
              animate: index < 6,
              child: ResourceCard(
                resource: resource,
                onTap: () => _openDetail(context, resource),
              ),
            );
          },
          childCount: state.items.length,
        ),
      ),
    );
  }
}
