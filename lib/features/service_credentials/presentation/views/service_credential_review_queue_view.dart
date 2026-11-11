import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/config/access_denied_view.dart';
import '../../../../core/config/route_names.dart';
import '../../../../core/errors/forbidden.dart';
import '../../../../core/errors/user_error_message.dart';
import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/theme/sac_font_size.dart';
import '../../../../core/widgets/sac_empty_state.dart';
import '../../../../core/widgets/sac_error_state.dart';
import '../../../../core/widgets/sac_filter_chip.dart';
import '../../../../core/widgets/sac_loading.dart';
import '../../../../core/widgets/sac_top_bar.dart';
import '../../../members/presentation/widgets/join_request_group.dart';
import '../../domain/entities/service_credential_review.dart';
import '../providers/service_credentials_providers.dart';
import '../utils/service_credential_labels.dart';
import '../utils/service_credentials_access.dart';
import '../widgets/review_item_row.dart';
import '../widgets/review_search_field.dart';
import '../widgets/service_credentials_skeleton.dart';

/// How long the reviewer must stop typing before the search is sent.
const Duration kServiceCredentialSearchDebounce = Duration(milliseconds: 350);

/// «Constancias por revisar»: the queue of the reviewer's scope (the server
/// filters it) with status tabs and their counts, search and pagination.
class ServiceCredentialReviewQueueView extends ConsumerStatefulWidget {
  const ServiceCredentialReviewQueueView({super.key});

  @override
  ConsumerState<ServiceCredentialReviewQueueView> createState() =>
      _ServiceCredentialReviewQueueViewState();
}

class _ServiceCredentialReviewQueueViewState
    extends ConsumerState<ServiceCredentialReviewQueueView> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;
  ReviewStatusFilter _filter = ReviewStatusFilter.pending;
  String _search = '';

  /// Last loaded data: keeps the tab counts on screen while another tab or a
  /// search loads.
  ReviewQueueState? _lastLoaded;

  ReviewQueueQuery get _query =>
      ReviewQueueQuery(status: _filter, search: _search);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController
      ..removeListener(_maybeLoadMore)
      ..dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter > 320) return;
    ref.read(reviewQueueProvider(_query).notifier).loadMore();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(kServiceCredentialSearchDebounce, () {
      if (!mounted || value.trim() == _search) return;
      setState(() => _search = value.trim());
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();
    if (_search.isNotEmpty) setState(() => _search = '');
  }

  Future<void> _refresh() async {
    final query = _query;
    ref.invalidate(reviewQueueProvider(query));
    ref.invalidate(reviewPendingCountProvider);
    try {
      await ref.read(reviewQueueProvider(query).future);
    } catch (_) {
      // The list renders its own error state.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(canReviewServiceCredentialsProvider)) {
      return const AccessDeniedView();
    }
    final c = context.sac;
    final query = _query;
    final async = ref.watch(reviewQueueProvider(query));
    ref.listen(reviewQueueProvider(query), (_, next) {
      final value = next.value;
      if (value != null) _lastLoaded = value;
    });
    final shown = async.value ?? _lastLoaded;

    return Scaffold(
      backgroundColor: c.background,
      appBar: SacTopBar(title: 'service_credentials.review.title'.tr()),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: ReviewSearchField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              onClear: _clearSearch,
            ),
          ),
          SizedBox(
            height: SacFilterChip.barHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: ReviewStatusFilter.values.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final filter = ReviewStatusFilter.values[i];
                return Center(
                  child: SacFilterChip(
                    label: reviewFilterLabel(filter),
                    selected: filter == _filter,
                    count: shown?.counts.of(filter),
                    onTap: () => setState(() => _filter = filter),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const ServiceCredentialsSkeleton(),
              error: (error, _) => isForbiddenFailure(error)
                  ? const ForbiddenView()
                  : SacErrorState(
                      title: 'service_credentials.review.error_title'.tr(),
                      message: userErrorMessage(error),
                      onRetry: () => ref.invalidate(reviewQueueProvider(query)),
                    ),
              data: (state) => _Body(
                state: state,
                filter: _filter,
                hasSearch: _search.isNotEmpty,
                controller: _scrollController,
                onRefresh: _refresh,
                onOpen: (item) => context.push(
                  RouteNames.serviceCredentialsReviewDetailPath(item.id),
                ),
                onLoadMore: () =>
                    ref.read(reviewQueueProvider(query).notifier).loadMore(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.state,
    required this.filter,
    required this.hasSearch,
    required this.controller,
    required this.onRefresh,
    required this.onOpen,
    required this.onLoadMore,
  });

  final ReviewQueueState state;
  final ReviewStatusFilter filter;
  final bool hasSearch;
  final ScrollController controller;
  final Future<void> Function() onRefresh;
  final void Function(ReviewItem item) onOpen;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final accent = SacAccent.of(context);

    if (state.items.isEmpty) {
      return RefreshIndicator(
        color: accent.color,
        onRefresh: onRefresh,
        child: SacEmptyState(
          scrollable: true,
          icon: hasSearch
              ? HugeIcons.strokeRoundedSearch01
              : HugeIcons.strokeRoundedCertificate01,
          title: hasSearch
              ? 'service_credentials.review.no_results_title'.tr()
              : 'service_credentials.review.empty_title'.tr(),
          body: hasSearch
              ? 'service_credentials.review.no_results_body'.tr()
              : switch (filter) {
                  ReviewStatusFilter.pending =>
                    'service_credentials.review.empty_pending'.tr(),
                  ReviewStatusFilter.approved =>
                    'service_credentials.review.empty_approved'.tr(),
                  ReviewStatusFilter.rejected =>
                    'service_credentials.review.empty_rejected'.tr(),
                },
        ),
      );
    }

    return RefreshIndicator(
      color: accent.color,
      onRefresh: onRefresh,
      child: ListView(
        controller: controller,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          JoinRequestGroupSection(
            title: reviewFilterLabel(filter),
            // The server total covers every page; never show less than what
            // is already on screen.
            count: state.total > state.items.length
                ? state.total
                : state.items.length,
            dotColor: switch (filter) {
              ReviewStatusFilter.pending => c.warning,
              ReviewStatusFilter.approved => c.success,
              ReviewStatusFilter.rejected => c.error,
            },
            children: [
              for (final item in state.items)
                ReviewItemRow(
                  key: ValueKey('review-item-${item.id}'),
                  item: item,
                  onTap: () => onOpen(item),
                ),
            ],
          ),
          if (state.isLoadingMore)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: SacLoadingSmall()),
            )
          else if (state.loadMoreFailed)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                children: [
                  Text(
                    'service_credentials.review.load_more_error'.tr(),
                    style: TextStyle(
                      fontSize: SacFontSize.bodySmall,
                      color: c.textSecondary,
                    ),
                  ),
                  TextButton(
                    onPressed: onLoadMore,
                    child: Text('common.retry'.tr()),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
