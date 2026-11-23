import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/dio_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/transfer_remote_data_source.dart';
import '../../data/repositories/transfer_repository_impl.dart';
import '../../../../core/providers/keep_alive_during.dart';
import '../../domain/entities/transfer_club_option.dart';
import '../../domain/entities/transfer_request.dart';
import '../../domain/repositories/transfer_repository.dart';

// ── Infrastructure ────────────────────────────────────────────────────────────

final transferRemoteDataSourceProvider =
    Provider<TransferRemoteDataSource>((ref) {
  return TransferRemoteDataSourceImpl(
    dio: ref.read(dioProvider),
    baseUrl: ref.read(apiBaseUrlProvider),
  );
});

final transferRepositoryProvider = Provider<TransferRepository>((ref) {
  return TransferRepositoryImpl(
    remoteDataSource: ref.read(transferRemoteDataSourceProvider),
  );
});

// ── List provider ─────────────────────────────────────────────────────────────

final myTransferRequestsProvider =
    FutureProvider.autoDispose<List<TransferRequest>>((ref) async {
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());
  final repo = ref.read(transferRepositoryProvider);
  final result = await repo.getMyTransferRequests(cancelToken: cancelToken);
  return result.fold(
    (failure) => throw Exception(failure.message),
    (requests) => requests,
  );
});

// ── Detail provider ───────────────────────────────────────────────────────────

final transferRequestDetailProvider =
    FutureProvider.autoDispose.family<TransferRequest, String>(
  (ref, requestId) async {
    // Cache-first: if the list is already loaded, reuse the matching item
    // instead of making a redundant network call. The list endpoint returns
    // all fields that TransferRequestDetailView needs (toSectionName,
    // toClubName, reason, reviewerComment, createdAt, status).
    final cached = ref
        .read(myTransferRequestsProvider)
        .value
        ?.where((t) => t.id == requestId)
        .firstOrNull;
    if (cached != null) return cached;

    // Fallback: list not loaded yet or item not found (e.g. deep-link entry).
    final cancelToken = CancelToken();
    ref.onDispose(() => cancelToken.cancel());
    final repo = ref.read(transferRepositoryProvider);
    final result = await repo.getTransferRequest(
      requestId,
      cancelToken: cancelToken,
    );
    return result.fold(
      (failure) => throw Exception(failure.message),
      (request) => request,
    );
  },
);

// ── Create notifier ───────────────────────────────────────────────────────────

class CreateTransferState {
  final bool isLoading;
  final TransferRequest? result;
  final String? errorMessage;

  const CreateTransferState({
    this.isLoading = false,
    this.result,
    this.errorMessage,
  });

  CreateTransferState copyWith({
    bool? isLoading,
    TransferRequest? result,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CreateTransferState(
      isLoading: isLoading ?? this.isLoading,
      result: result ?? this.result,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class CreateTransferNotifier extends Notifier<CreateTransferState> {
  @override
  CreateTransferState build() => const CreateTransferState();

  Future<bool> create({
    required int fromSectionId,
    required int toSectionId,
    String? reason,
  }) {
    // The sheet may close before the answer arrives: keep the notifier
    // alive across the await so the result still lands.
    return ref.keepAliveDuring(() async {
      state = state.copyWith(isLoading: true, clearError: true);

      final repo = ref.read(transferRepositoryProvider);
      final result = await repo.createTransferRequest(
        fromSectionId: fromSectionId,
        toSectionId: toSectionId,
        reason: reason,
      );

      return result.fold(
        (failure) {
          state =
              state.copyWith(isLoading: false, errorMessage: failure.message);
          return false;
        },
        (transfer) {
          state = state.copyWith(isLoading: false, result: transfer);
          ref.invalidate(myTransferRequestsProvider);
          return true;
        },
      );
    });
  }

  void reset() => state = const CreateTransferState();
}

final createTransferProvider =
    NotifierProvider.autoDispose<CreateTransferNotifier, CreateTransferState>(
  CreateTransferNotifier.new,
);

// ── Destination clubs ─────────────────────────────────────────────────────────

/// Clubs of a local field for the new request, with their section of the
/// member's club type. Key: `(localFieldId, clubTypeId)`.
final destinationClubsProvider = FutureProvider.autoDispose
    .family<List<TransferClubOption>, (int, int)>((ref, key) async {
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());
  final result = await ref.read(transferRepositoryProvider).getDestinationClubs(
        localFieldId: key.$1,
        clubTypeId: key.$2,
        cancelToken: cancelToken,
      );
  return result.fold(
    (failure) => throw Exception(failure.message),
    (clubs) => clubs,
  );
});
