import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/certification.dart';
import '../../domain/entities/certification_detail.dart';
import '../../domain/entities/user_certification.dart';
import '../../domain/entities/certification_progress.dart';
import '../../domain/repositories/certifications_repository.dart';
import '../datasources/certifications_remote_data_source.dart';

/// Implementación del repositorio de certificaciones.
class CertificationsRepositoryImpl implements CertificationsRepository {
  final CertificationsRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  CertificationsRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  // ── Helpers ──────────────────────────────────────────────────────────────────

  Future<bool> get _isConnected => networkInfo.isConnected;

  Left<Failure, T> _networkFailure<T>() =>
      const Left(NetworkFailure(message: 'No hay conexion a internet'));

  Left<Failure, T> _serverFailure<T>(ServerException e) =>
      Left(ServerFailure(message: e.message, code: e.code));

  Left<Failure, T> _authFailure<T>(AuthException e) =>
      Left(AuthFailure(message: e.message, code: e.code));

  Left<Failure, T> _unexpectedFailure<T>(Object e) =>
      Left(UnexpectedFailure(message: e.toString()));

  // ── Métodos ───────────────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, List<Certification>>> getCertifications() async {
    if (!await _isConnected) return _networkFailure();
    try {
      final models = await remoteDataSource.getCertifications();
      return Right(models.map((m) => m.toEntity()).toList());
    } on ServerException catch (e) {
      return _serverFailure(e);
    } on AuthException catch (e) {
      return _authFailure(e);
    } catch (e) {
      return _unexpectedFailure(e);
    }
  }

  @override
  Future<Either<Failure, CertificationDetail>> getCertificationDetail(
      int certificationId) async {
    if (!await _isConnected) return _networkFailure();
    try {
      final model =
          await remoteDataSource.getCertificationDetail(certificationId);
      return Right(model.toEntity());
    } on ServerException catch (e) {
      return _serverFailure(e);
    } on AuthException catch (e) {
      return _authFailure(e);
    } catch (e) {
      return _unexpectedFailure(e);
    }
  }

  @override
  Future<Either<Failure, List<UserCertification>>> getUserCertifications(
      String userId) async {
    if (!await _isConnected) return _networkFailure();
    try {
      final models = await remoteDataSource.getUserCertifications(userId);
      return Right(models.map((m) => m.toEntity()).toList());
    } on ServerException catch (e) {
      return _serverFailure(e);
    } on AuthException catch (e) {
      return _authFailure(e);
    } catch (e) {
      return _unexpectedFailure(e);
    }
  }

  @override
  Future<Either<Failure, CertificationProgress>> getCertificationProgress(
      String userId, int certificationId) async {
    if (!await _isConnected) return _networkFailure();
    try {
      final model = await remoteDataSource.getCertificationProgress(
          userId, certificationId);
      return Right(model.toEntity());
    } on ServerException catch (e) {
      return _serverFailure(e);
    } on AuthException catch (e) {
      return _authFailure(e);
    } catch (e) {
      return _unexpectedFailure(e);
    }
  }

  @override
  Future<Either<Failure, void>> enrollCertification(
      String userId, int certificationId) async {
    if (!await _isConnected) return _networkFailure();
    try {
      await remoteDataSource.enrollCertification(userId, certificationId);
      return const Right(null);
    } on ServerException catch (e) {
      return _serverFailure(e);
    } on AuthException catch (e) {
      return _authFailure(e);
    } catch (e) {
      return _unexpectedFailure(e);
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> updateSectionProgress(
    String userId,
    int certificationId,
    int moduleId,
    int sectionId,
    bool completed,
  ) async {
    if (!await _isConnected) return _networkFailure();
    try {
      final result = await remoteDataSource.updateSectionProgress(
        userId,
        certificationId,
        moduleId,
        sectionId,
        completed,
      );
      return Right(result);
    } on ServerException catch (e) {
      return _serverFailure(e);
    } on AuthException catch (e) {
      return _authFailure(e);
    } catch (e) {
      return _unexpectedFailure(e);
    }
  }

  @override
  Future<Either<Failure, void>> unenrollCertification(
      String userId, int certificationId) async {
    if (!await _isConnected) return _networkFailure();
    try {
      await remoteDataSource.unenrollCertification(userId, certificationId);
      return const Right(null);
    } on ServerException catch (e) {
      return _serverFailure(e);
    } on AuthException catch (e) {
      return _authFailure(e);
    } catch (e) {
      return _unexpectedFailure(e);
    }
  }
}
