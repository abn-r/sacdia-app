import 'dart:async';

import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/keep_alive_during.dart';
import '../../../auth/presentation/providers/auth_providers.dart'
    show apiBaseUrlProvider;
import '../../../../providers/dio_provider.dart';
import '../../data/datasources/supervision_clubs_remote_data_source.dart';
import '../../data/repositories/supervision_clubs_repository_impl.dart';
import '../../domain/entities/supervision_club.dart';
import '../../domain/repositories/supervision_clubs_repository.dart';
import 'supervision_providers.dart';

const int kSupervisionClubsPageSize = 25;

/// Quiet period before a typed search hits the server.
const Duration _searchDebounce = Duration(milliseconds: 350);

final supervisionClubsRemoteDataSourceProvider =
    Provider<SupervisionClubsRemoteDataSource>((ref) {
  return SupervisionClubsRemoteDataSourceImpl(
    dio: ref.read(dioProvider),
    baseUrl: ref.read(apiBaseUrlProvider),
  );
});

final supervisionClubsRepositoryProvider =
    Provider<SupervisionClubsRepository>((ref) {
  return SupervisionClubsRepositoryImpl(
    remoteDataSource: ref.read(supervisionClubsRemoteDataSourceProvider),
  );
});

const Object _unset = Object();

class SupervisionClubsState extends Equatable {
  final SupervisionClubActiveFilter filter;
  final String search;
  final List<SupervisionClubListItem> items;
  final int total;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;

  /// A [SupervisionLoadException] from the last load, or null.
  final Object? error;

  const SupervisionClubsState({
    this.filter = SupervisionClubActiveFilter.all,
    this.search = '',
    this.items = const [],
    this.total = 0,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = false,
    this.error,
  });

  SupervisionClubsState copyWith({
    SupervisionClubActiveFilter? filter,
    String? search,
    List<SupervisionClubListItem>? items,
    int? total,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    Object? error = _unset,
  }) {
    return SupervisionClubsState(
      filter: filter ?? this.filter,
      search: search ?? this.search,
      items: items ?? this.items,
      total: total ?? this.total,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: identical(error, _unset) ? this.error : error,
    );
  }

  @override
  List<Object?> get props => [
        filter,
        search,
        items,
        total,
        isLoading,
        isLoadingMore,
        hasMore,
        error,
      ];
}

class SupervisionClubsNotifier extends Notifier<SupervisionClubsState> {
  int _generation = 0;
  int _page = 1;
  SupervisionClubActiveFilter _filter = SupervisionClubActiveFilter.all;
  String _search = '';
  CancelToken _cancelToken = CancelToken();
  Timer? _debounce;

  /// Completes when the debounce fires or is dropped.
  Completer<void>? _debounceDone;

  SupervisionClubsRepository get _repo =>
      ref.read(supervisionClubsRepositoryProvider);

  @override
  SupervisionClubsState build() {
    ref.onDispose(() {
      _cancelToken.cancel();
      // A pending search must not load after the provider is gone.
      _generation++;
      _clearDebounce();
    });
    // Filter and search survive `ref.invalidate`.
    final initial = SupervisionClubsState(
      filter: _filter,
      search: _search,
      isLoading: true,
    );
    unawaited(_loadFirstPage(
      generation: _startGeneration(),
      filter: _filter,
      search: _search,
    ));
    return initial;
  }

  int _startGeneration() {
    _cancelToken.cancel();
    _cancelToken = CancelToken();
    return ++_generation;
  }

  void _clearDebounce() {
    _debounce?.cancel();
    _debounce = null;
    final done = _debounceDone;
    _debounceDone = null;
    if (done != null && !done.isCompleted) done.complete();
  }

  Future<void> _loadFirstPage({
    required int generation,
    required SupervisionClubActiveFilter filter,
    required String search,
  }) =>
      ref.keepAliveDuring(() async {
        final result = await _repo.getClubs(
          filter: filter,
          search: search,
          page: 1,
          limit: kSupervisionClubsPageSize,
          cancelToken: _cancelToken,
        );
        if (generation != _generation) return;
        result.fold(
          (failure) {
            state = state.copyWith(
              isLoading: false,
              isLoadingMore: false,
              error: SupervisionLoadException.fromFailure(failure),
            );
          },
          (page) {
            _page = page.page;
            state = state.copyWith(
              items: page.items,
              total: page.total,
              isLoading: false,
              isLoadingMore: false,
              hasMore: page.hasMore,
              error: null,
            );
          },
        );
      });

  /// Reloads the first page, keeping the visible items until it arrives.
  Future<void> refresh() {
    _clearDebounce();
    final generation = _startGeneration();
    state = state.copyWith(
      isLoading: true,
      isLoadingMore: false,
      error: null,
    );
    return _loadFirstPage(
      generation: generation,
      filter: _filter,
      search: _search,
    );
  }

  void setFilter(SupervisionClubActiveFilter filter) {
    if (filter == _filter) return;
    _filter = filter;
    _clearDebounce();
    final generation = _startGeneration();
    state = state.copyWith(
      filter: filter,
      isLoading: true,
      isLoadingMore: false,
      error: null,
    );
    unawaited(_loadFirstPage(
      generation: generation,
      filter: filter,
      search: _search,
    ));
  }

  /// Trims, ignores an unchanged value and loads after a short quiet period.
  void setSearch(String search) {
    final term = search.trim();
    if (term == _search) return;
    _search = term;
    _clearDebounce();
    // Drop any in-flight response of the previous term right away.
    final generation = _startGeneration();
    state = state.copyWith(
      search: term,
      isLoading: true,
      isLoadingMore: false,
      error: null,
    );
    // The wait holds the provider (`keepAliveDuring`), so a caller that does
    // not watch it still gets the reload. A newer search, filter or refresh
    // drops the wait and moves the generation on, which skips this load.
    final done = Completer<void>();
    _debounceDone = done;
    _debounce = Timer(_searchDebounce, () {
      _debounce = null;
      if (!done.isCompleted) done.complete();
    });
    unawaited(ref.keepAliveDuring(() async {
      await done.future;
      if (generation != _generation) return;
      await _loadFirstPage(
        generation: generation,
        filter: _filter,
        search: _search,
      );
    }));
  }

  Future<void> loadMore() {
    final current = state;
    if (current.isLoading || current.isLoadingMore || !current.hasMore) {
      return Future.value();
    }
    final generation = _generation;
    final nextPage = _page + 1;
    state = current.copyWith(isLoadingMore: true, error: null);
    return ref.keepAliveDuring(() async {
      final result = await _repo.getClubs(
        filter: current.filter,
        search: current.search,
        page: nextPage,
        limit: kSupervisionClubsPageSize,
        cancelToken: _cancelToken,
      );
      if (generation != _generation) return;
      result.fold(
        (failure) {
          state = state.copyWith(
            isLoadingMore: false,
            error: SupervisionLoadException.fromFailure(failure),
          );
        },
        (page) {
          _page = nextPage;
          final known = state.items.map((e) => e.id).toSet();
          final merged = [
            ...state.items,
            ...page.items.where((e) => !known.contains(e.id)),
          ];
          state = state.copyWith(
            items: merged,
            total: page.total,
            isLoadingMore: false,
            hasMore: page.items.isNotEmpty && page.hasMore,
            error: null,
          );
        },
      );
    });
  }
}

final supervisionClubsProvider = NotifierProvider.autoDispose<
    SupervisionClubsNotifier, SupervisionClubsState>(
  SupervisionClubsNotifier.new,
);

/// Profile, overview and leadership of one club, by club id.
final supervisionClubSummaryProvider = FutureProvider.autoDispose
    .family<SupervisionClubSummary, int>((ref, clubId) async {
  final repository = ref.read(supervisionClubsRepositoryProvider);
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());
  final result = await repository.getClubSummary(
    clubId,
    cancelToken: cancelToken,
  );
  return result.fold(
    (failure) => throw SupervisionLoadException.fromFailure(failure),
    (summary) => summary,
  );
});
