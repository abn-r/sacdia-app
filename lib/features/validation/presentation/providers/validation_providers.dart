import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/dio_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/validation_remote_data_source.dart';
import '../../data/repositories/validation_repository_impl.dart';
import '../../domain/entities/validation.dart';
import '../../domain/repositories/validation_repository.dart';

// ── Infrastructure ────────────────────────────────────────────────────────────

final validationRemoteDataSourceProvider =
    Provider<ValidationRemoteDataSource>((ref) {
  return ValidationRemoteDataSourceImpl(
    dio: ref.read(dioProvider),
    baseUrl: ref.read(apiBaseUrlProvider),
  );
});

final validationRepositoryProvider = Provider<ValidationRepository>((ref) {
  return ValidationRepositoryImpl(
    remoteDataSource: ref.read(validationRemoteDataSourceProvider),
    networkInfo: ref.read(networkInfoProvider),
  );
});

// ── Validation history ────────────────────────────────────────────────────────

/// Clave para el provider de historial: (entityType, entityId)
typedef ValidationKey = ({ValidationEntityType entityType, int entityId});

final validationHistoryProvider = FutureProvider.autoDispose
    .family<List<ValidationHistoryEntry>, ValidationKey>(
  (ref, key) async {
    final cancelToken = CancelToken();
    ref.onDispose(() => cancelToken.cancel());
    final repo = ref.read(validationRepositoryProvider);
    final result = await repo.getValidationHistory(
      entityType: key.entityType,
      entityId: key.entityId,
      cancelToken: cancelToken,
    );
    return result.fold(
      (failure) => throw Exception(failure.message),
      (history) => history,
    );
  },
);

// ── Eligibility ───────────────────────────────────────────────────────────────

/// Caches eligibility results per userId with a 5-minute timer: the instance
/// is kept alive while any listener is active and is auto-disposed 5 minutes
/// after the last listener is removed, preventing unbounded growth when
/// checking eligibility for many different members in a session.
final eligibilityProvider =
    FutureProvider.autoDispose.family<EligibilityResult, String>(
  (ref, userId) async {
    final cancelToken = CancelToken();
    final link = ref.keepAlive();
    Timer? timer;
    ref.onCancel(() {
      timer = Timer(const Duration(minutes: 5), () {
        link.close();
      });
    });
    ref.onResume(() {
      timer?.cancel();
    });
    ref.onDispose(() {
      timer?.cancel();
      cancelToken.cancel();
    });
    final repo = ref.read(validationRepositoryProvider);
    final result = await repo.checkEligibility(
      userId: userId,
      cancelToken: cancelToken,
    );
    return result.fold(
      (failure) => throw Exception(failure.message),
      (r) => r,
    );
  },
);

// ── Submit validation notifier ────────────────────────────────────────────────

class SubmitValidationState {
  final bool isLoading;
  final ValidationSubmitResult? result;
  final String? errorMessage;

  const SubmitValidationState({
    this.isLoading = false,
    this.result,
    this.errorMessage,
  });

  SubmitValidationState copyWith({
    bool? isLoading,
    ValidationSubmitResult? result,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SubmitValidationState(
      isLoading: isLoading ?? this.isLoading,
      result: result ?? this.result,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class SubmitValidationNotifier
    extends AutoDisposeNotifier<SubmitValidationState> {
  @override
  SubmitValidationState build() => const SubmitValidationState();

  Future<bool> submit({
    required ValidationEntityType entityType,
    required int entityId,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    final repo = ref.read(validationRepositoryProvider);
    final result = await repo.submitForReview(
      entityType: entityType,
      entityId: entityId,
    );

    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
        return false;
      },
      (submitResult) {
        state = state.copyWith(isLoading: false, result: submitResult);
        // Refresh history after submit
        ref.invalidate(validationHistoryProvider(
          (entityType: entityType, entityId: entityId),
        ));
        return true;
      },
    );
  }

  void reset() => state = const SubmitValidationState();
}

final submitValidationProvider = NotifierProvider.autoDispose<
    SubmitValidationNotifier, SubmitValidationState>(
  SubmitValidationNotifier.new,
);
