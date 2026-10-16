import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/legal_document.dart';
import '../../domain/entities/legal_status.dart';
import '../../domain/repositories/legal_repository.dart';
import '../datasources/legal_remote_data_source.dart';

/// Implementación del repositorio legal.
///
/// Conserva [Failure.errorCode] para que la UI distinga
/// `LEGAL_VERSION_MISMATCH` de un error genérico.
class LegalRepositoryImpl implements LegalRepository {
  final LegalRemoteDataSource remoteDataSource;

  LegalRepositoryImpl({required this.remoteDataSource});

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Right(await action());
    } on ServerException catch (e) {
      return Left(ServerFailure(
          message: e.message, code: e.code, errorCode: e.errorCode));
    } on AuthException catch (e) {
      return Left(AuthFailure(
          message: e.message, code: e.code, errorCode: e.errorCode));
    } on ConnectionException catch (e) {
      return Left(ConnectionFailure(message: e.message));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<LegalDocument>>> getCurrentDocuments() =>
      _guard(() async {
        final models = await remoteDataSource.getCurrentDocuments();
        return models.map((m) => m.toEntity()).toList();
      });

  @override
  Future<Either<Failure, LegalStatus>> getMyStatus() => _guard(() async {
        final model = await remoteDataSource.getMyStatus();
        return model.toEntity();
      });

  @override
  Future<Either<Failure, LegalStatus>> accept({
    required String termsVersion,
    required String privacyVersion,
  }) =>
      _guard(() async {
        final model = await remoteDataSource.accept(
          termsVersion: termsVersion,
          privacyVersion: privacyVersion,
        );
        return model.toEntity();
      });
}
