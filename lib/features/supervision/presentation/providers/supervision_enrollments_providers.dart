import 'dart:async';

import 'package:dartz/dartz.dart' show Either;
import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/providers/keep_alive_during.dart';
import '../../../auth/presentation/providers/auth_providers.dart'
    show apiBaseUrlProvider;
import '../../../../providers/dio_provider.dart';
import '../../data/datasources/supervision_enrollments_remote_data_source.dart';
import '../../data/repositories/supervision_enrollments_repository_impl.dart';
import '../../domain/entities/supervision_enrollment.dart';
import '../../domain/repositories/supervision_enrollments_repository.dart';
import 'supervision_providers.dart';

const int kSupervisionEnrollmentsPageSize = 20;

/// Business codes after which the local queue is known to be stale.
const Set<String> _staleQueueCodes = {
  'CE_ENROLLMENT_NOT_PENDING',
  'CE_ENROLLMENT_NOT_FOUND',
};

final supervisionEnrollmentsRemoteDataSourceProvider =
    Provider<SupervisionEnrollmentsRemoteDataSource>((ref) {
  return SupervisionEnrollmentsRemoteDataSourceImpl(
    dio: ref.read(dioProvider),
    baseUrl: ref.read(apiBaseUrlProvider),
  );
});

final supervisionEnrollmentsRepositoryProvider =
    Provider<SupervisionEnrollmentsRepository>((ref) {
  return SupervisionEnrollmentsRepositoryImpl(
    remoteDataSource: ref.read(supervisionEnrollmentsRemoteDataSourceProvider),
  );
});

const Object _unset = Object();

class SupervisionEnrollmentsState extends Equatable {
  final SupervisionEnrollmentStatus filter;
  final String search;
  final List<SupervisionEnrollment> items;
  final SupervisionEnrollmentCounts? counts;
  final int total;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;

  /// A [SupervisionLoadException] from the last list load, or null.
  final Object? error;

  /// Backend `code` of the last failed approve/reject (e.g. `CE_SELF_REVIEW`).
  final String? lastActionErrorCode;

  const SupervisionEnrollmentsState({
    this.filter = SupervisionEnrollmentStatus.pendingValidation,
    this.search = '',
    this.items = const [],
    this.counts,
    this.total = 0,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = false,
    this.error,
    this.lastActionErrorCode,
  });

  SupervisionEnrollmentsState copyWith({
    SupervisionEnrollmentStatus? filter,
    String? search,
    List<SupervisionEnrollment>? items,
    SupervisionEnrollmentCounts? counts,
    int? total,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    Object? error = _unset,
    Object? lastActionErrorCode = _unset,
  }) {
    return SupervisionEnrollmentsState(
      filter: filter ?? this.filter,
      search: search ?? this.search,
      items: items ?? this.items,
      counts: counts ?? this.counts,
      total: total ?? this.total,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: identical(error, _unset) ? this.error : error,
      lastActionErrorCode: identical(lastActionErrorCode, _unset)
          ? this.lastActionErrorCode
          : lastActionErrorCode as String?,
    );
  }

  @override
  List<Object?> get props => [
        filter,
        search,
        items,
        counts,
        total,
        isLoading,
        isLoadingMore,
        hasMore,
        error,
        lastActionErrorCode,
      ];
}

class SupervisionEnrollmentsNotifier
    extends Notifier<SupervisionEnrollmentsState> {
  int _generation = 0;
  int _page = 1;
  CancelToken _cancelToken = CancelToken();

  SupervisionEnrollmentsRepository get _repo =>
      ref.read(supervisionEnrollmentsRepositoryProvider);

  @override
  SupervisionEnrollmentsState build() {
    ref.onDispose(() => _cancelToken.cancel());
    const initial = SupervisionEnrollmentsState(isLoading: true);
    unawaited(_loadFirstPage(
      generation: _startGeneration(),
      filter: initial.filter,
      search: initial.search,
    ));
    return initial;
  }

  int _startGeneration() {
    _cancelToken.cancel();
    _cancelToken = CancelToken();
    return ++_generation;
  }

  Future<void> _loadFirstPage({
    required int generation,
    required SupervisionEnrollmentStatus filter,
    required String search,
  }) =>
      ref.keepAliveDuring(() async {
        final result = await _repo.getQueue(
          status: filter,
          search: search,
          page: 1,
          limit: kSupervisionEnrollmentsPageSize,
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
              counts: page.counts,
              total: page.total,
              isLoading: false,
              isLoadingMore: false,
              hasMore: page.items.length < page.total,
              error: null,
            );
          },
        );
      });

  /// Reloads the first page for the current filter and search, keeping the
  /// visible items until the response arrives.
  Future<void> refresh() {
    final generation = _startGeneration();
    state = state.copyWith(
      isLoading: true,
      isLoadingMore: false,
      error: null,
    );
    return _loadFirstPage(
      generation: generation,
      filter: state.filter,
      search: state.search,
    );
  }

  void setFilter(SupervisionEnrollmentStatus filter) {
    if (filter == state.filter) return;
    _reset(filter: filter, search: state.search);
  }

  /// The caller debounces.
  void setSearch(String search) {
    final value = search.trim();
    if (value == state.search) return;
    _reset(filter: state.filter, search: value);
  }

  void _reset({
    required SupervisionEnrollmentStatus filter,
    required String search,
  }) {
    final generation = _startGeneration();
    state = state.copyWith(
      filter: filter,
      search: search,
      items: const [],
      total: 0,
      isLoading: true,
      isLoadingMore: false,
      hasMore: false,
      error: null,
    );
    unawaited(_loadFirstPage(
      generation: generation,
      filter: filter,
      search: search,
    ));
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
      final result = await _repo.getQueue(
        status: current.filter,
        search: current.search,
        page: nextPage,
        limit: kSupervisionEnrollmentsPageSize,
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
            counts: page.counts,
            total: page.total,
            isLoadingMore: false,
            hasMore: page.items.isNotEmpty && merged.length < page.total,
            error: null,
          );
        },
      );
    });
  }

  /// Returns null on success, or the server message on failure.
  Future<String?> approve(String id) => _act(
        id,
        (repo) => repo.approve(id),
        approved: true,
      );

  /// Returns null on success, or the server message on failure.
  Future<String?> reject(String id, String reason) => _act(
        id,
        (repo) => repo.reject(id, reason),
        approved: false,
      );

  Future<String?> _act(
    String id,
    Future<Either<Failure, SupervisionEnrollment>> Function(
      SupervisionEnrollmentsRepository repo,
    ) call, {
    required bool approved,
  }) {
    state = state.copyWith(lastActionErrorCode: null);
    return ref.keepAliveDuring(() async {
      final result = await call(_repo);
      return await result.fold<Future<String?>>(
        (failure) async {
          final code = failure.errorCode;
          state = state.copyWith(lastActionErrorCode: code ?? 'UNKNOWN');
          if (code != null && _staleQueueCodes.contains(code)) {
            await refresh();
          }
          return failure.message;
        },
        (updated) async {
          _applySuccess(id, updated, approved);
          ref.invalidate(supervisionPendingCountsProvider);
          return null;
        },
      );
    });
  }

  void _applySuccess(String id, SupervisionEnrollment updated, bool approved) {
    final current = state;
    final index = current.items.indexWhere((e) => e.id == id);
    final previous = index >= 0 ? current.items[index] : null;
    final matchesFilter = updated.status == current.filter;

    var items = current.items;
    var total = current.total;
    if (index >= 0) {
      items = [...items];
      if (matchesFilter) {
        items[index] = updated;
      } else {
        items.removeAt(index);
        total = total > 0 ? total - 1 : 0;
      }
    }

    var counts = current.counts;
    final wasPending = previous == null ||
        previous.status == SupervisionEnrollmentStatus.pendingValidation;
    if (counts != null && wasPending) {
      counts = SupervisionEnrollmentCounts(
        pending: counts.pending > 0 ? counts.pending - 1 : 0,
        approved: counts.approved + (approved ? 1 : 0),
        rejected: counts.rejected + (approved ? 0 : 1),
      );
    }

    state = current.copyWith(
      items: items,
      counts: counts,
      total: total,
      hasMore: items.length < total,
      lastActionErrorCode: null,
    );
  }
}

final supervisionEnrollmentsProvider = NotifierProvider.autoDispose<
    SupervisionEnrollmentsNotifier, SupervisionEnrollmentsState>(
  SupervisionEnrollmentsNotifier.new,
);
