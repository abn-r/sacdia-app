import 'package:dartz/dartz.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/usecases/cancellation_token.dart';
import 'package:sacdia_app/features/investiture_requests/domain/entities/investiture_request.dart';
import 'package:sacdia_app/features/investiture_requests/domain/entities/investiture_resolution.dart';
import 'package:sacdia_app/features/investiture_requests/domain/entities/own_investiture_entry.dart';
import 'package:sacdia_app/features/investiture_requests/domain/entities/person_status.dart';
import 'package:sacdia_app/features/investiture_requests/domain/entities/presentation_context.dart';
import 'package:sacdia_app/features/investiture_requests/domain/entities/yearbook_entry.dart';
import 'package:sacdia_app/features/investiture_requests/domain/repositories/investiture_requests_repository.dart';

/// Fake manual del repositorio: cada método registra la llamada y devuelve el
/// resultado configurado (por defecto, un `Right` con datos mínimos).
class FakeInvestitureRequestsRepository
    implements InvestitureRequestsRepository {
  FakeInvestitureRequestsRepository();

  PresentationContext context = const PresentationContext(
    clubSectionId: 4,
    ecclesiasticalYearId: 9,
    window: WindowState(openToday: true),
    yearOpen: true,
    candidates: [],
  );
  InvestitureRequest? openRequest;
  List<OwnInvestitureEntry> ownHistory = const [];
  List<OwnInvestitureEntry> sectionHistory = const [];
  List<YearbookEntry> yearbook = const [];
  List<InvestitureRequest> authorizerRequests = const [];
  InvestitureRequest? authorizerRequest;
  InvestitureResolution? resolution;

  /// Si no es nulo, toda acción de escritura devuelve este fallo.
  Failure? writeFailure;
  Failure? readFailure;

  int contextCalls = 0;
  int openRequestCalls = 0;
  int authorizerListCalls = 0;
  final calls = <String>[];
  Map<String, Object?>? lastArgs;

  static const _emptyRequest = InvestitureRequest(
    requestId: 'r1',
    clubSectionId: 4,
    ecclesiasticalYearId: 9,
    people: [],
  );

  Either<Failure, T> _read<T>(T value) =>
      readFailure != null ? Left(readFailure!) : Right(value);

  Either<Failure, T> _write<T>(T value) =>
      writeFailure != null ? Left(writeFailure!) : Right(value);

  @override
  Future<Either<Failure, PresentationContext>> presentationContext(
    int sectionId,
    int yearId, {
    RequestCancelToken? cancelToken,
  }) async {
    contextCalls++;
    return _read(context);
  }

  @override
  Future<Either<Failure, InvestitureRequest?>> openRequestFor(
    int sectionId,
    int yearId, {
    RequestCancelToken? cancelToken,
  }) async {
    openRequestCalls++;
    return _read(openRequest);
  }

  @override
  Future<Either<Failure, InvestitureRequest>> present({
    required int sectionId,
    required int yearId,
    required DateTime investitureDate,
    required List<int> enrollmentIds,
  }) async {
    calls.add('present');
    lastArgs = {
      'sectionId': sectionId,
      'yearId': yearId,
      'date': investitureDate,
      'enrollmentIds': enrollmentIds,
    };
    return _write(openRequest ?? _emptyRequest);
  }

  @override
  Future<Either<Failure, InvestitureRequest>> addPeople({
    required String requestId,
    required DateTime investitureDate,
    required List<int> enrollmentIds,
  }) async {
    calls.add('addPeople');
    lastArgs = {
      'requestId': requestId,
      'date': investitureDate,
      'enrollmentIds': enrollmentIds,
    };
    return _write(openRequest ?? _emptyRequest);
  }

  @override
  Future<Either<Failure, RequestPerson>> removePerson({
    required String requestId,
    required String personId,
  }) async {
    calls.add('removePerson');
    lastArgs = {'requestId': requestId, 'personId': personId};
    return _write(
      RequestPerson(
        personId: personId,
        userId: 'u1',
        classId: 3,
        enrollmentId: 11,
        investitureDate: DateTime(2026, 11, 15),
        status: PersonStatus.removed,
      ),
    );
  }

  @override
  Future<Either<Failure, InvestitureRequest>> changeDates({
    required String requestId,
    required DateTime investitureDate,
    required List<String> personIds,
  }) async {
    calls.add('changeDates');
    lastArgs = {
      'requestId': requestId,
      'date': investitureDate,
      'personIds': personIds,
    };
    return _write(openRequest ?? _emptyRequest);
  }

  @override
  Future<Either<Failure, List<OwnInvestitureEntry>>> getOwnHistory({
    RequestCancelToken? cancelToken,
  }) async =>
      _read(ownHistory);

  @override
  Future<Either<Failure, List<OwnInvestitureEntry>>> getSectionHistory(
    int sectionId, {
    RequestCancelToken? cancelToken,
  }) async =>
      _read(sectionHistory);

  @override
  Future<Either<Failure, List<YearbookEntry>>> getSectionYearbook(
    int sectionId, {
    RequestCancelToken? cancelToken,
  }) async =>
      _read(yearbook);

  @override
  Future<Either<Failure, List<InvestitureRequest>>> listForAuthorizer(
    int yearId, {
    RequestCancelToken? cancelToken,
  }) async {
    authorizerListCalls++;
    return _read(authorizerRequests);
  }

  @override
  Future<Either<Failure, InvestitureRequest>> readForAuthorizer(
    String requestId, {
    RequestCancelToken? cancelToken,
  }) async =>
      _read(authorizerRequest ?? _emptyRequest);

  @override
  Future<Either<Failure, InvestitureResolution>> resolve({
    required String requestId,
    List<InvestDecision> invest = const [],
    List<RejectDecision> reject = const [],
  }) async {
    calls.add('resolve');
    lastArgs = {'requestId': requestId, 'invest': invest, 'reject': reject};
    return _write(
      resolution ??
          InvestitureResolution(
            requestId: requestId,
            invested: const [],
            rejectedByPerson: const [],
            rejectedBySystem: const [],
            retired: const [],
            blocked: const [],
            alreadyResolved: const [],
          ),
    );
  }
}
