import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/dio_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../members/presentation/providers/members_providers.dart';
import '../../data/datasources/enrollment_remote_data_source.dart';
import '../../data/repositories/enrollment_repository_impl.dart';
import '../../domain/entities/enrollment.dart';
import '../../domain/repositories/enrollment_repository.dart';
import '../../domain/usecases/create_enrollment.dart';
import '../../domain/usecases/get_current_enrollment.dart';

// ── Infrastructure ────────────────────────────────────────────────────────────

final enrollmentRemoteDataSourceProvider =
    Provider<EnrollmentRemoteDataSource>((ref) {
  return EnrollmentRemoteDataSourceImpl(
    dio: ref.read(dioProvider),
    baseUrl: ref.read(apiBaseUrlProvider),
  );
});

final enrollmentRepositoryProvider = Provider<EnrollmentRepository>((ref) {
  return EnrollmentRepositoryImpl(
    remoteDataSource: ref.read(enrollmentRemoteDataSourceProvider),
    networkInfo: ref.read(networkInfoProvider),
  );
});

// ── Use cases ─────────────────────────────────────────────────────────────────

final getCurrentEnrollmentUseCaseProvider =
    Provider<GetCurrentEnrollment>((ref) {
  return GetCurrentEnrollment(ref.read(enrollmentRepositoryProvider));
});

final createEnrollmentUseCaseProvider = Provider<CreateEnrollment>((ref) {
  return CreateEnrollment(ref.read(enrollmentRepositoryProvider));
});

// ── Current enrollment (auto-resolves club context) ──────────────────────────

/// Carga la inscripción activa del usuario en su sección de club actual.
/// Depende de [clubContextProvider] como fuente de verdad.
final currentEnrollmentProvider =
    FutureProvider<Enrollment?>((ref) async {
  final context = await ref.watch(clubContextProvider.future);
  if (context == null) return null;

  final useCase = ref.read(getCurrentEnrollmentUseCaseProvider);
  final result = await useCase(
    GetCurrentEnrollmentParams(
      clubId: context.clubId.toString(),
      sectionId: context.sectionId,
    ),
  );

  return result.fold(
    (failure) => throw Exception(failure.message),
    (enrollment) => enrollment,
  );
});

// ── Create / Update notifier ──────────────────────────────────────────────────

class EnrollmentFormState {
  final bool isLoading;
  final Enrollment? result;
  final String? errorMessage;

  const EnrollmentFormState({
    this.isLoading = false,
    this.result,
    this.errorMessage,
  });

  EnrollmentFormState copyWith({
    bool? isLoading,
    Enrollment? result,
    String? errorMessage,
    bool clearError = false,
  }) {
    return EnrollmentFormState(
      isLoading: isLoading ?? this.isLoading,
      result: result ?? this.result,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class EnrollmentFormNotifier
    extends AutoDisposeNotifier<EnrollmentFormState> {
  @override
  EnrollmentFormState build() => const EnrollmentFormState();

  Future<bool> create({
    required String clubId,
    required int sectionId,
    required String address,
    required List<String> meetingDays,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    final useCase = ref.read(createEnrollmentUseCaseProvider);
    final result = await useCase(
      CreateEnrollmentParams(
        clubId: clubId,
        sectionId: sectionId,
        address: address,
        meetingDays: meetingDays,
      ),
    );

    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
        return false;
      },
      (enrollment) {
        state = state.copyWith(isLoading: false, result: enrollment);
        // Invalidate so the card refreshes after creation
        ref.invalidate(currentEnrollmentProvider);
        return true;
      },
    );
  }

  Future<bool> update({
    required String clubId,
    required int sectionId,
    required int enrollmentId,
    String? address,
    List<String>? meetingDays,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    final repo = ref.read(enrollmentRepositoryProvider);
    final result = await repo.updateEnrollment(
      clubId: clubId,
      sectionId: sectionId,
      enrollmentId: enrollmentId,
      address: address,
      meetingDays: meetingDays,
    );

    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
        return false;
      },
      (enrollment) {
        state = state.copyWith(isLoading: false, result: enrollment);
        ref.invalidate(currentEnrollmentProvider);
        return true;
      },
    );
  }

  void reset() => state = const EnrollmentFormState();
}

final enrollmentFormProvider =
    NotifierProvider.autoDispose<EnrollmentFormNotifier, EnrollmentFormState>(
  EnrollmentFormNotifier.new,
);
