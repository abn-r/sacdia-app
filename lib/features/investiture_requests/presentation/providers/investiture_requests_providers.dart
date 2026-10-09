import 'package:dartz/dartz.dart' show Either;
import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../../../providers/dio_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/investiture_requests_remote_data_source.dart';
import '../../data/repositories/investiture_requests_repository_impl.dart';
import '../../domain/entities/investiture_request.dart';
import '../../domain/entities/investiture_resolution.dart';
import '../../domain/entities/own_investiture_entry.dart';
import '../../domain/entities/presentation_context.dart';
import '../../domain/entities/yearbook_entry.dart';
import '../../domain/repositories/investiture_requests_repository.dart';

// ── Infraestructura ──────────────────────────────────────────────────────────

/// Clave de consulta: sección y año eclesiástico.
class SectionYearQuery extends Equatable {
  const SectionYearQuery({required this.sectionId, required this.yearId});

  final int sectionId;
  final int yearId;

  @override
  List<Object?> get props => [sectionId, yearId];
}

final investitureRequestsRemoteDataSourceProvider =
    Provider<InvestitureRequestsRemoteDataSource>((ref) {
  return InvestitureRequestsRemoteDataSourceImpl(
    dio: ref.watch(dioProvider),
    baseUrl: ref.watch(apiBaseUrlProvider),
  );
});

final investitureRequestsRepositoryProvider =
    Provider<InvestitureRequestsRepository>((ref) {
  return InvestitureRequestsRepositoryImpl(
    remoteDataSource: ref.watch(investitureRequestsRemoteDataSourceProvider),
  );
});

// ── Lectura: directiva de la sección ─────────────────────────────────────────

final presentationContextProvider = FutureProvider.autoDispose
    .family<PresentationContext, SectionYearQuery>((ref, q) async {
  final cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);
  final result = await ref
      .watch(investitureRequestsRepositoryProvider)
      .presentationContext(q.sectionId, q.yearId, cancelToken: cancelToken);
  return result.fold((failure) => throw failure, (value) => value);
});

/// Solicitud con pendientes de la sección y el año; `null` si no hay.
final openRequestProvider = FutureProvider.autoDispose
    .family<InvestitureRequest?, SectionYearQuery>((ref, q) async {
  final cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);
  final result = await ref
      .watch(investitureRequestsRepositoryProvider)
      .openRequestFor(q.sectionId, q.yearId, cancelToken: cancelToken);
  return result.fold((failure) => throw failure, (value) => value);
});

// ── Lectura: historial y anuario ─────────────────────────────────────────────

final ownInvestitureHistoryProvider =
    FutureProvider.autoDispose<List<OwnInvestitureEntry>>((ref) async {
  final cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);
  final result = await ref
      .watch(investitureRequestsRepositoryProvider)
      .getOwnHistory(cancelToken: cancelToken);
  return result.fold((failure) => throw failure, (value) => value);
});

final sectionInvestitureHistoryProvider = FutureProvider.autoDispose
    .family<List<OwnInvestitureEntry>, int>((ref, sectionId) async {
  final cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);
  final result = await ref
      .watch(investitureRequestsRepositoryProvider)
      .getSectionHistory(sectionId, cancelToken: cancelToken);
  return result.fold((failure) => throw failure, (value) => value);
});

final sectionYearbookProvider = FutureProvider.autoDispose
    .family<List<YearbookEntry>, int>((ref, sectionId) async {
  final cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);
  final result = await ref
      .watch(investitureRequestsRepositoryProvider)
      .getSectionYearbook(sectionId, cancelToken: cancelToken);
  return result.fold((failure) => throw failure, (value) => value);
});

// ── Lectura: autorizador ─────────────────────────────────────────────────────

/// Solicitudes visibles para el autorizador en el año (family por `yearId`).
final authorizerRequestsProvider = FutureProvider.autoDispose
    .family<List<InvestitureRequest>, int>((ref, yearId) async {
  final cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);
  final result = await ref
      .watch(investitureRequestsRepositoryProvider)
      .listForAuthorizer(yearId, cancelToken: cancelToken);
  return result.fold((failure) => throw failure, (value) => value);
});

/// Detalle de una solicitud para el autorizador (family por `requestId`).
final authorizerRequestProvider = FutureProvider.autoDispose
    .family<InvestitureRequest, String>((ref, requestId) async {
  final cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);
  final result = await ref
      .watch(investitureRequestsRepositoryProvider)
      .readForAuthorizer(requestId, cancelToken: cancelToken);
  return result.fold((failure) => throw failure, (value) => value);
});

// ── Estado de las acciones ───────────────────────────────────────────────────

/// Estado compartido por las acciones de escritura (misma forma que
/// `InvestitureActionState` del feature legado).
class RequestActionState extends Equatable {
  const RequestActionState({
    this.isLoading = false,
    this.errorMessage,
    this.success = false,
  });

  final bool isLoading;
  final String? errorMessage;
  final bool success;

  RequestActionState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool? success,
  }) {
    return RequestActionState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      success: success ?? this.success,
    );
  }

  @override
  List<Object?> get props => [isLoading, errorMessage, success];
}

/// Base de los notifiers de escritura de la directiva: ejecuta [run], publica
/// loading/success/error e invalida las lecturas de la sección si salió bien.
abstract class _SectionActionNotifier
    extends AutoDisposeFamilyNotifier<RequestActionState, SectionYearQuery> {
  @override
  RequestActionState build(SectionYearQuery arg) => const RequestActionState();

  InvestitureRequestsRepository get _repo =>
      ref.read(investitureRequestsRepositoryProvider);

  Future<bool> _execute<T>(Future<Either<Failure, T>> Function() run) async {
    state = state.copyWith(isLoading: true, errorMessage: null, success: false);
    final result = await run();
    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
        return false;
      },
      (_) {
        state = state.copyWith(isLoading: false, success: true);
        ref.invalidate(presentationContextProvider(arg));
        ref.invalidate(openRequestProvider(arg));
        return true;
      },
    );
  }

  void reset() => state = const RequestActionState();
}

/// Presenta personas en una solicitud nueva.
class PresentNotifier extends _SectionActionNotifier {
  Future<bool> submit({
    required DateTime investitureDate,
    required List<int> enrollmentIds,
  }) =>
      _execute(
        () => _repo.present(
          sectionId: arg.sectionId,
          yearId: arg.yearId,
          investitureDate: investitureDate,
          enrollmentIds: enrollmentIds,
        ),
      );
}

/// Agrega personas a la solicitud abierta.
class AddPeopleNotifier extends _SectionActionNotifier {
  Future<bool> submit({
    required String requestId,
    required DateTime investitureDate,
    required List<int> enrollmentIds,
  }) =>
      _execute(
        () => _repo.addPeople(
          requestId: requestId,
          investitureDate: investitureDate,
          enrollmentIds: enrollmentIds,
        ),
      );
}

/// Quita a una persona pendiente (sin correo).
class RemovePersonNotifier extends _SectionActionNotifier {
  Future<bool> submit({
    required String requestId,
    required String personId,
  }) =>
      _execute(
        () => _repo.removePerson(requestId: requestId, personId: personId),
      );
}

/// Cambia la fecha de las personas pendientes seleccionadas.
class ChangeDatesNotifier extends _SectionActionNotifier {
  Future<bool> submit({
    required String requestId,
    required DateTime investitureDate,
    required List<String> personIds,
  }) =>
      _execute(
        () => _repo.changeDates(
          requestId: requestId,
          investitureDate: investitureDate,
          personIds: personIds,
        ),
      );
}

final presentNotifierProvider = NotifierProvider.autoDispose
    .family<PresentNotifier, RequestActionState, SectionYearQuery>(
  PresentNotifier.new,
);

final addPeopleNotifierProvider = NotifierProvider.autoDispose
    .family<AddPeopleNotifier, RequestActionState, SectionYearQuery>(
  AddPeopleNotifier.new,
);

final removePersonNotifierProvider = NotifierProvider.autoDispose
    .family<RemovePersonNotifier, RequestActionState, SectionYearQuery>(
  RemovePersonNotifier.new,
);

final changeDatesNotifierProvider = NotifierProvider.autoDispose
    .family<ChangeDatesNotifier, RequestActionState, SectionYearQuery>(
  ChangeDatesNotifier.new,
);

// ── Autorizador: resolver ────────────────────────────────────────────────────

/// Estado de la resolución: además del flag de éxito conserva el resumen.
class ResolveState extends Equatable {
  const ResolveState({
    this.isLoading = false,
    this.errorMessage,
    this.success = false,
    this.resolution,
  });

  final bool isLoading;
  final String? errorMessage;
  final bool success;
  final InvestitureResolution? resolution;

  @override
  List<Object?> get props => [isLoading, errorMessage, success, resolution];
}

/// Confirma las decisiones del autorizador sobre una solicitud (family por
/// `requestId`).
class ResolveNotifier extends AutoDisposeFamilyNotifier<ResolveState, String> {
  @override
  ResolveState build(String arg) => const ResolveState();

  Future<bool> submit({
    List<InvestDecision> invest = const [],
    List<RejectDecision> reject = const [],
  }) async {
    state = const ResolveState(isLoading: true);
    final result = await ref
        .read(investitureRequestsRepositoryProvider)
        .resolve(requestId: arg, invest: invest, reject: reject);

    return result.fold(
      (failure) {
        state = ResolveState(errorMessage: failure.message);
        return false;
      },
      (resolution) {
        state = ResolveState(success: true, resolution: resolution);
        ref.invalidate(authorizerRequestsProvider);
        ref.invalidate(authorizerRequestProvider(arg));
        return true;
      },
    );
  }

  void reset() => state = const ResolveState();
}

final resolveNotifierProvider = NotifierProvider.autoDispose
    .family<ResolveNotifier, ResolveState, String>(ResolveNotifier.new);
