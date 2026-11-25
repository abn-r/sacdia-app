import 'dart:async';

import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/keep_alive_during.dart';
import '../../../auth/presentation/providers/auth_providers.dart'
    show apiBaseUrlProvider;
import '../../../../providers/dio_provider.dart';
import '../../data/datasources/supervision_reports_remote_data_source.dart';
import '../../data/repositories/supervision_reports_repository_impl.dart';
import '../../domain/entities/supervision_report.dart';
import '../../domain/repositories/supervision_reports_repository.dart';
import 'supervision_providers.dart';

const int kSupervisionCompliancePageSize = 50;
const int kSupervisionReportsPageSize = 25;

final supervisionReportsRemoteDataSourceProvider =
    Provider<SupervisionReportsRemoteDataSource>((ref) {
  return SupervisionReportsRemoteDataSourceImpl(
    dio: ref.read(dioProvider),
    baseUrl: ref.read(apiBaseUrlProvider),
  );
});

final supervisionReportsRepositoryProvider =
    Provider<SupervisionReportsRepository>((ref) {
  return SupervisionReportsRepositoryImpl(
    remoteDataSource: ref.read(supervisionReportsRemoteDataSourceProvider),
  );
});

/// Months of the active ecclesiastical year the selector offers.
final supervisionReportPeriodsProvider =
    FutureProvider.autoDispose<SupervisionReportPeriods>((ref) async {
  final repository = ref.read(supervisionReportsRepositoryProvider);
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());
  final result = await repository.getPeriods(cancelToken: cancelToken);
  return result.fold(
    (failure) => throw SupervisionLoadException.fromFailure(failure),
    (periods) => periods,
  );
});

const Object _unset = Object();

class SupervisionComplianceState extends Equatable {
  final SupervisionReportCounts? totals;
  final int clubCount;
  final List<SupervisionClubCompliance> clubs;
  final int total;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;

  /// A [SupervisionLoadException] from the last load, or null.
  final Object? error;

  const SupervisionComplianceState({
    this.totals,
    this.clubCount = 0,
    this.clubs = const [],
    this.total = 0,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = false,
    this.error,
  });

  SupervisionComplianceState copyWith({
    Object? totals = _unset,
    int? clubCount,
    List<SupervisionClubCompliance>? clubs,
    int? total,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    Object? error = _unset,
  }) {
    return SupervisionComplianceState(
      totals: identical(totals, _unset)
          ? this.totals
          : totals as SupervisionReportCounts?,
      clubCount: clubCount ?? this.clubCount,
      clubs: clubs ?? this.clubs,
      total: total ?? this.total,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: identical(error, _unset) ? this.error : error,
    );
  }

  @override
  List<Object?> get props => [
        totals,
        clubCount,
        clubs,
        total,
        isLoading,
        isLoadingMore,
        hasMore,
        error
      ];
}

class SupervisionComplianceNotifier
    extends Notifier<SupervisionComplianceState> {
  SupervisionComplianceNotifier(this.period);

  final SupervisionPeriodKey period;

  int _generation = 0;
  int _page = 1;
  CancelToken _cancelToken = CancelToken();

  SupervisionReportsRepository get _repo =>
      ref.read(supervisionReportsRepositoryProvider);

  @override
  SupervisionComplianceState build() {
    ref.onDispose(() => _cancelToken.cancel());
    unawaited(_loadFirstPage(_startGeneration()));
    return const SupervisionComplianceState(isLoading: true);
  }

  int _startGeneration() {
    _cancelToken.cancel();
    _cancelToken = CancelToken();
    return ++_generation;
  }

  Future<void> _loadFirstPage(int generation) => ref.keepAliveDuring(() async {
        final result = await _repo.getCompliance(
          period: period,
          page: 1,
          limit: kSupervisionCompliancePageSize,
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
              totals: page.totals,
              clubCount: page.clubCount,
              clubs: page.clubs,
              total: page.total,
              isLoading: false,
              isLoadingMore: false,
              hasMore: page.hasMore,
              error: null,
            );
          },
        );
      });

  /// Reloads the first page, keeping the visible clubs until it arrives.
  Future<void> refresh() {
    final generation = _startGeneration();
    state = state.copyWith(isLoading: true, isLoadingMore: false, error: null);
    return _loadFirstPage(generation);
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
      final result = await _repo.getCompliance(
        period: period,
        page: nextPage,
        limit: kSupervisionCompliancePageSize,
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
          final known = state.clubs.map((e) => e.clubId).toSet();
          final merged = [
            ...state.clubs,
            ...page.clubs.where((e) => !known.contains(e.clubId)),
          ];
          state = state.copyWith(
            clubs: merged,
            total: page.total,
            isLoadingMore: false,
            hasMore: page.clubs.isNotEmpty && page.hasMore,
            error: null,
          );
        },
      );
    });
  }
}

final supervisionComplianceProvider = NotifierProvider.autoDispose.family<
    SupervisionComplianceNotifier,
    SupervisionComplianceState,
    SupervisionPeriodKey>(SupervisionComplianceNotifier.new);

class SupervisionMonthlyReportsState extends Equatable {
  final List<SupervisionMonthlyReport> items;
  final int total;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;

  /// A [SupervisionLoadException] from the last load, or null.
  final Object? error;

  const SupervisionMonthlyReportsState({
    this.items = const [],
    this.total = 0,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = false,
    this.error,
  });

  SupervisionMonthlyReportsState copyWith({
    List<SupervisionMonthlyReport>? items,
    int? total,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    Object? error = _unset,
  }) {
    return SupervisionMonthlyReportsState(
      items: items ?? this.items,
      total: total ?? this.total,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: identical(error, _unset) ? this.error : error,
    );
  }

  @override
  List<Object?> get props =>
      [items, total, isLoading, isLoadingMore, hasMore, error];
}

class SupervisionMonthlyReportsNotifier
    extends Notifier<SupervisionMonthlyReportsState> {
  SupervisionMonthlyReportsNotifier(this.period);

  final SupervisionPeriodKey period;

  int _generation = 0;
  int _page = 1;
  CancelToken _cancelToken = CancelToken();

  SupervisionReportsRepository get _repo =>
      ref.read(supervisionReportsRepositoryProvider);

  @override
  SupervisionMonthlyReportsState build() {
    ref.onDispose(() => _cancelToken.cancel());
    unawaited(_loadFirstPage(_startGeneration()));
    return const SupervisionMonthlyReportsState(isLoading: true);
  }

  int _startGeneration() {
    _cancelToken.cancel();
    _cancelToken = CancelToken();
    return ++_generation;
  }

  Future<void> _loadFirstPage(int generation) => ref.keepAliveDuring(() async {
        final result = await _repo.getReports(
          period: period,
          page: 1,
          limit: kSupervisionReportsPageSize,
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

  /// Reloads the first page, keeping the visible reports until it arrives.
  Future<void> refresh() {
    final generation = _startGeneration();
    state = state.copyWith(isLoading: true, isLoadingMore: false, error: null);
    return _loadFirstPage(generation);
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
      final result = await _repo.getReports(
        period: period,
        page: nextPage,
        limit: kSupervisionReportsPageSize,
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

final supervisionMonthlyReportsProvider = NotifierProvider.autoDispose.family<
    SupervisionMonthlyReportsNotifier,
    SupervisionMonthlyReportsState,
    SupervisionPeriodKey>(SupervisionMonthlyReportsNotifier.new);
