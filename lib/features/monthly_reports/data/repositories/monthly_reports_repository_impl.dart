import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/monthly_report.dart';
import '../../domain/repositories/monthly_reports_repository.dart';
import '../datasources/monthly_reports_remote_data_source.dart';

/// Implementación del repositorio de informes mensuales
class MonthlyReportsRepositoryImpl implements MonthlyReportsRepository {
  final MonthlyReportsRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  MonthlyReportsRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  Future<bool> get _isConnected => networkInfo.isConnected;

  Left<Failure, T> _networkFailure<T>() =>
      const Left(NetworkFailure(message: 'No hay conexion a internet'));

  Left<Failure, T> _serverFailure<T>(ServerException e) =>
      Left(ServerFailure(message: e.message, code: e.code));

  Left<Failure, T> _authFailure<T>(AuthException e) =>
      Left(AuthFailure(message: e.message, code: e.code));

  Left<Failure, T> _unexpectedFailure<T>(Object e) =>
      Left(UnexpectedFailure(message: e.toString()));

  @override
  Future<Either<Failure, MonthlyReportPreview>> getPreview(
    int enrollmentId, {
    required int month,
    required int year,
  }) async {
    if (!await _isConnected) return _networkFailure();
    try {
      final model = await remoteDataSource.getPreview(
        enrollmentId,
        month: month,
        year: year,
      );
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
  Future<Either<Failure, List<MonthlyReport>>> getReportsByEnrollment(
      int enrollmentId) async {
    if (!await _isConnected) return _networkFailure();
    try {
      final models =
          await remoteDataSource.getReportsByEnrollment(enrollmentId);
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
  Future<Either<Failure, MonthlyReport>> getReportDetail(
      int reportId) async {
    if (!await _isConnected) return _networkFailure();
    try {
      final model = await remoteDataSource.getReportDetail(reportId);
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
  Future<Either<Failure, String>> getReportPdfUrl(int reportId) async {
    if (!await _isConnected) return _networkFailure();
    try {
      final url = await remoteDataSource.getReportPdfUrl(reportId);
      return Right(url);
    } on ServerException catch (e) {
      return _serverFailure(e);
    } on AuthException catch (e) {
      return _authFailure(e);
    } catch (e) {
      return _unexpectedFailure(e);
    }
  }
}
