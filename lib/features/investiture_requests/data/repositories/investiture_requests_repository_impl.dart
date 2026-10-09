import 'package:dartz/dartz.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/cancel_token_adapter.dart';
import '../../../../core/usecases/cancellation_token.dart';
import '../../domain/entities/investiture_request.dart';
import '../../domain/entities/investiture_resolution.dart';
import '../../domain/entities/own_investiture_entry.dart';
import '../../domain/entities/presentation_context.dart';
import '../../domain/entities/yearbook_entry.dart';
import '../../domain/repositories/investiture_requests_repository.dart';
import '../datasources/investiture_requests_remote_data_source.dart';

class InvestitureRequestsRepositoryImpl
    implements InvestitureRequestsRepository {
  InvestitureRequestsRepositoryImpl({required this.remoteDataSource});

  final InvestitureRequestsRemoteDataSource remoteDataSource;

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Right(await action());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, PresentationContext>> presentationContext(
    int sectionId,
    int yearId, {
    RequestCancelToken? cancelToken,
  }) =>
      _guard(
        () => remoteDataSource.getPresentationContext(
          sectionId,
          yearId,
          cancelToken: cancelToken.asDioCancelToken(),
        ),
      );

  @override
  Future<Either<Failure, InvestitureRequest?>> openRequestFor(
    int sectionId,
    int yearId, {
    RequestCancelToken? cancelToken,
  }) =>
      _guard<InvestitureRequest?>(
        () => remoteDataSource.getSectionRequest(
          sectionId,
          yearId,
          cancelToken: cancelToken.asDioCancelToken(),
        ),
      );

  @override
  Future<Either<Failure, InvestitureRequest>> present({
    required int sectionId,
    required int yearId,
    required DateTime investitureDate,
    required List<int> enrollmentIds,
  }) =>
      _guard(
        () => remoteDataSource.present(
          sectionId: sectionId,
          yearId: yearId,
          investitureDate: investitureDate,
          enrollmentIds: enrollmentIds,
        ),
      );

  @override
  Future<Either<Failure, InvestitureRequest>> addPeople({
    required String requestId,
    required DateTime investitureDate,
    required List<int> enrollmentIds,
  }) =>
      _guard(
        () => remoteDataSource.addPeople(
          requestId: requestId,
          investitureDate: investitureDate,
          enrollmentIds: enrollmentIds,
        ),
      );

  @override
  Future<Either<Failure, RequestPerson>> removePerson({
    required String requestId,
    required String personId,
  }) =>
      _guard(
        () => remoteDataSource.removePerson(
          requestId: requestId,
          personId: personId,
        ),
      );

  @override
  Future<Either<Failure, InvestitureRequest>> changeDates({
    required String requestId,
    required DateTime investitureDate,
    required List<String> personIds,
  }) =>
      _guard(
        () => remoteDataSource.changeDates(
          requestId: requestId,
          investitureDate: investitureDate,
          personIds: personIds,
        ),
      );

  @override
  Future<Either<Failure, List<OwnInvestitureEntry>>> getOwnHistory({
    RequestCancelToken? cancelToken,
  }) =>
      _guard(
        () => remoteDataSource.getOwnHistory(
          cancelToken: cancelToken.asDioCancelToken(),
        ),
      );

  @override
  Future<Either<Failure, List<OwnInvestitureEntry>>> getSectionHistory(
    int sectionId, {
    RequestCancelToken? cancelToken,
  }) =>
      _guard(
        () => remoteDataSource.getSectionHistory(
          sectionId,
          cancelToken: cancelToken.asDioCancelToken(),
        ),
      );

  @override
  Future<Either<Failure, List<YearbookEntry>>> getSectionYearbook(
    int sectionId, {
    RequestCancelToken? cancelToken,
  }) =>
      _guard(
        () => remoteDataSource.getSectionYearbook(
          sectionId,
          cancelToken: cancelToken.asDioCancelToken(),
        ),
      );

  @override
  Future<Either<Failure, List<InvestitureRequest>>> listForAuthorizer(
    int yearId, {
    RequestCancelToken? cancelToken,
  }) =>
      _guard(
        () => remoteDataSource.listForAuthorizer(
          yearId,
          cancelToken: cancelToken.asDioCancelToken(),
        ),
      );

  @override
  Future<Either<Failure, InvestitureRequest>> readForAuthorizer(
    String requestId, {
    RequestCancelToken? cancelToken,
  }) =>
      _guard(
        () => remoteDataSource.readForAuthorizer(
          requestId,
          cancelToken: cancelToken.asDioCancelToken(),
        ),
      );

  @override
  Future<Either<Failure, InvestitureResolution>> resolve({
    required String requestId,
    List<InvestDecision> invest = const [],
    List<RejectDecision> reject = const [],
  }) =>
      _guard(
        () => remoteDataSource.resolve(
          requestId: requestId,
          invest: invest,
          reject: reject,
        ),
      );
}
