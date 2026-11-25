import 'dart:async';

import 'package:dartz/dartz.dart' show Either, Unit;
import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/providers/keep_alive_during.dart';
import '../../../auth/presentation/providers/auth_providers.dart'
    show apiBaseUrlProvider;
import '../../../../providers/dio_provider.dart';
import '../../data/datasources/supervision_folders_remote_data_source.dart';
import '../../data/repositories/supervision_folders_repository_impl.dart';
import '../../domain/entities/supervision_folder.dart';
import '../../domain/repositories/supervision_folders_repository.dart';
import 'supervision_providers.dart';

const int kSupervisionFoldersPageSize = 25;

/// Business codes after which the cached folder detail is known to be stale.
const Set<String> _staleDetailCodes = {
  'ANNUAL_FOLDER_STATUS_INVALID_FOR_EVALUATE',
  'ANNUAL_FOLDER_STATUS_INVALID_FOR_REOPEN',
  'ANNUAL_FOLDER_SECTION_TERMINAL',
  'ANNUAL_FOLDER_SECTION_NOT_PREAPPROVED',
  'ANNUAL_FOLDER_STATUS_CONFLICT',
  'ANNUAL_FOLDER_NOT_FOUND',
};

final supervisionFoldersRemoteDataSourceProvider =
    Provider<SupervisionFoldersRemoteDataSource>((ref) {
  return SupervisionFoldersRemoteDataSourceImpl(
    dio: ref.read(dioProvider),
    baseUrl: ref.read(apiBaseUrlProvider),
  );
});

final supervisionFoldersRepositoryProvider =
    Provider<SupervisionFoldersRepository>((ref) {
  return SupervisionFoldersRepositoryImpl(
    remoteDataSource: ref.read(supervisionFoldersRemoteDataSourceProvider),
  );
});

const Object _unset = Object();

class SupervisionFoldersQueueState extends Equatable {
  final SupervisionFolderQueueFilter filter;
  final List<SupervisionFolderQueueItem> items;
  final int total;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;

  /// A [SupervisionLoadException] from the last load, or null.
  final Object? error;

  const SupervisionFoldersQueueState({
    this.filter = SupervisionFolderQueueFilter.needsReview,
    this.items = const [],
    this.total = 0,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = false,
    this.error,
  });

  SupervisionFoldersQueueState copyWith({
    SupervisionFolderQueueFilter? filter,
    List<SupervisionFolderQueueItem>? items,
    int? total,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    Object? error = _unset,
  }) {
    return SupervisionFoldersQueueState(
      filter: filter ?? this.filter,
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
      [filter, items, total, isLoading, isLoadingMore, hasMore, error];
}

class SupervisionFoldersQueueNotifier
    extends Notifier<SupervisionFoldersQueueState> {
  int _generation = 0;
  int _page = 1;
  SupervisionFolderQueueFilter _filter =
      SupervisionFolderQueueFilter.needsReview;
  CancelToken _cancelToken = CancelToken();

  SupervisionFoldersRepository get _repo =>
      ref.read(supervisionFoldersRepositoryProvider);

  @override
  SupervisionFoldersQueueState build() {
    ref.onDispose(() => _cancelToken.cancel());
    // `_filter` survives `ref.invalidate` (the action service invalidates the
    // queue), so a reload keeps the filter the user picked.
    final initial = SupervisionFoldersQueueState(
      filter: _filter,
      isLoading: true,
    );
    unawaited(_loadFirstPage(
      generation: _startGeneration(),
      filter: _filter,
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
    required SupervisionFolderQueueFilter filter,
  }) =>
      ref.keepAliveDuring(() async {
        final result = await _repo.getQueue(
          filter: filter,
          page: 1,
          limit: kSupervisionFoldersPageSize,
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
              hasMore: page.items.length < page.total,
              error: null,
            );
          },
        );
      });

  /// Reloads the first page for the current filter, keeping the visible items
  /// until the response arrives.
  Future<void> refresh() {
    final generation = _startGeneration();
    state = state.copyWith(
      isLoading: true,
      isLoadingMore: false,
      error: null,
    );
    return _loadFirstPage(generation: generation, filter: state.filter);
  }

  void setFilter(SupervisionFolderQueueFilter filter) {
    if (filter == state.filter) return;
    _filter = filter;
    final generation = _startGeneration();
    state = state.copyWith(
      filter: filter,
      items: const [],
      total: 0,
      isLoading: true,
      isLoadingMore: false,
      hasMore: false,
      error: null,
    );
    unawaited(_loadFirstPage(generation: generation, filter: filter));
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
        filter: current.filter,
        page: nextPage,
        limit: kSupervisionFoldersPageSize,
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
            hasMore: page.items.isNotEmpty && merged.length < page.total,
            error: null,
          );
        },
      );
    });
  }
}

final supervisionFoldersQueueProvider = NotifierProvider.autoDispose<
    SupervisionFoldersQueueNotifier, SupervisionFoldersQueueState>(
  SupervisionFoldersQueueNotifier.new,
);

/// One folder with sections, evidences and evaluations.
final supervisionFolderDetailProvider = FutureProvider.autoDispose
    .family<SupervisionFolderDetail, String>((ref, folderId) async {
  final repository = ref.read(supervisionFoldersRepositoryProvider);
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());
  final result = await repository.getFolder(
    folderId,
    cancelToken: cancelToken,
  );
  return result.fold(
    (failure) => throw SupervisionLoadException.fromFailure(failure),
    (detail) => detail,
  );
});

class SupervisionFolderActionResult {
  const SupervisionFolderActionResult({
    this.ok = false,
    this.errorMessage,
    this.errorCode,
  });

  final bool ok;
  final String? errorMessage;
  final String? errorCode;
}

/// Evaluation actions on a folder. Stateless: safe to `ref.read` from a view.
class SupervisionFolderActions {
  const SupervisionFolderActions(this._ref);

  final Ref _ref;

  String? _cleanNotes(String? notes) {
    final trimmed = notes?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  Future<SupervisionFolderActionResult> evaluateSection(
    String folderId,
    String sectionId, {
    required int earnedPoints,
    String? notes,
  }) =>
      _run(
        folderId,
        (repo) => repo.evaluateSection(
          folderId,
          sectionId,
          earnedPoints: earnedPoints,
          notes: _cleanNotes(notes),
        ),
      );

  Future<SupervisionFolderActionResult> reopenSection(
    String folderId,
    String sectionId,
  ) =>
      _run(folderId, (repo) => repo.reopenSection(folderId, sectionId));

  Future<SupervisionFolderActionResult> confirmUnion(
    String folderId,
    String sectionId, {
    required bool approve,
    String? notes,
  }) =>
      _run(
        folderId,
        (repo) => repo.confirmUnion(
          folderId,
          sectionId,
          approve: approve,
          notes: _cleanNotes(notes),
        ),
      );

  Future<SupervisionFolderActionResult> closeFolder(String folderId) =>
      _run(folderId, (repo) => repo.closeFolder(folderId));

  /// A blank [note] clears the reviewer note.
  Future<SupervisionFolderActionResult> saveReviewerNote(
    String folderId,
    String evidenceId,
    String? note,
  ) =>
      _run(
        folderId,
        (repo) => repo.saveReviewerNote(evidenceId, _cleanNotes(note)),
      );

  Future<SupervisionFolderActionResult> _run(
    String folderId,
    Future<Either<Failure, Unit>> Function(SupervisionFoldersRepository repo)
        call,
  ) =>
      _ref.keepAliveDuring(() async {
        final repository = _ref.read(supervisionFoldersRepositoryProvider);
        final result = await call(repository);
        return result.fold(
          (failure) {
            if (_staleDetailCodes.contains(failure.errorCode)) {
              _ref.invalidate(supervisionFolderDetailProvider(folderId));
            }
            return SupervisionFolderActionResult(
              errorMessage: failure.message,
              errorCode: failure.errorCode,
            );
          },
          (_) {
            _ref.invalidate(supervisionFolderDetailProvider(folderId));
            _ref.invalidate(supervisionFoldersQueueProvider);
            _ref.invalidate(supervisionPendingCountsProvider);
            return const SupervisionFolderActionResult(ok: true);
          },
        );
      });
}

final supervisionFolderActionsProvider =
    Provider.autoDispose<SupervisionFolderActions>(
  (ref) => SupervisionFolderActions(ref),
);
