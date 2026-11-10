import 'package:dartz/dartz.dart';

import '../../../../core/consent/consent_evidence.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/service_credential.dart';
import '../../domain/entities/service_credential_review.dart';
import '../../domain/repositories/service_credentials_repository.dart';
import '../datasources/service_credentials_remote_data_source.dart';

class ServiceCredentialsRepositoryImpl implements ServiceCredentialsRepository {
  ServiceCredentialsRepositoryImpl({required this.remoteDataSource});

  final ServiceCredentialsRemoteDataSource remoteDataSource;

  /// Conserva [Failure.errorCode] (`SERVICE_CREDENTIAL_*`): la UI traduce por
  /// `code`, nunca por `details` ni por el texto del servidor.
  Future<Either<Failure, T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Right(await action());
    } on ServerException catch (e) {
      return Left(ServerFailure(
        message: e.message,
        code: e.code,
        errorCode: e.errorCode,
      ));
    } on AuthException catch (e) {
      return Left(AuthFailure(
        message: e.message,
        code: e.code,
        errorCode: e.errorCode,
      ));
    } on ConnectionException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<ServiceCredential>>> getMine() =>
      _guard(remoteDataSource.getMine);

  @override
  Future<Either<Failure, ServiceCredential>> submit({
    required ServiceCredentialDraft draft,
    required ConsentEvidenceLocalFile file,
    void Function(ServiceCredentialSubmitPhase phase)? onPhase,
    void Function(double progress)? onProgress,
  }) =>
      _guard(() => remoteDataSource.submit(
            draft: draft,
            file: file,
            onPhase: onPhase,
            onProgress: onProgress,
          ));

  @override
  Future<Either<Failure, Unit>> withdraw(String id) => _guard(() async {
        await remoteDataSource.withdraw(id);
        return unit;
      });

  @override
  Future<Either<Failure, ReviewPage>> getReviewQueue({
    required ReviewStatusFilter status,
    String search = '',
    int page = 1,
    int limit = 20,
  }) =>
      _guard(() => remoteDataSource.getReviewQueue(
            status: status,
            search: search,
            page: page,
            limit: limit,
          ));

  @override
  Future<Either<Failure, ReviewDetail>> getReviewDetail(String id) =>
      _guard(() => remoteDataSource.getReviewDetail(id));

  @override
  Future<Either<Failure, Unit>> approve(String id, {DateTime? expiresAt}) =>
      _guard(() async {
        await remoteDataSource.approve(id, expiresAt: expiresAt);
        return unit;
      });

  @override
  Future<Either<Failure, Unit>> reject(String id, {required String reason}) =>
      _guard(() async {
        await remoteDataSource.reject(id, reason: reason);
        return unit;
      });
}
