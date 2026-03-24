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
    final repo = ref.read(validationRepositoryProvider);
    final result = await repo.getValidationHistory(
      entityType: key.entityType,
      entityId: key.entityId,
    );
    return result.fold(
      (failure) => throw Exception(failure.message),
      (history) => history,
    );
  },
);

// ── Eligibility ───────────────────────────────────────────────────────────────

final eligibilityProvider =
    FutureProvider.autoDispose.family<EligibilityResult, String>(
  (ref, userId) async {
    final repo = ref.read(validationRepositoryProvider);
    final result = await repo.checkEligibility(userId: userId);
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
