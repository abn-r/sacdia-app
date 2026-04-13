import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/camporee.dart';
import '../../domain/entities/camporee_member.dart';
import '../../domain/entities/camporee_payment.dart';
import '../../domain/repositories/camporees_repository.dart';
import '../datasources/camporees_remote_data_source.dart';

/// Implementación del repositorio de camporees.
class CamporeesRepositoryImpl implements CamporeesRepository {
  final CamporeesRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  CamporeesRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  // ── Helpers ──────────────────────────────────────────────────────────────────

  Left<Failure, T> _serverFailure<T>(ServerException e) =>
      Left(ServerFailure(message: e.message, code: e.code));

  Left<Failure, T> _authFailure<T>(AuthException e) =>
      Left(AuthFailure(message: e.message, code: e.code));

  Left<Failure, T> _unexpectedFailure<T>(Object e) =>
      Left(UnexpectedFailure(message: e.toString()));

  // ── Métodos ───────────────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, List<Camporee>>> getCamporees({bool? active, CancelToken? cancelToken}) async {
    try {
      final models = await remoteDataSource.getCamporees(active: active, cancelToken: cancelToken);
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
  Future<Either<Failure, Camporee>> getCamporeeDetail(int camporeeId, {CancelToken? cancelToken}) async {
    try {
      final model = await remoteDataSource.getCamporeeDetail(camporeeId, cancelToken: cancelToken);
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
  Future<Either<Failure, CamporeeMember>> registerMember(
    int camporeeId, {
    required String userId,
    required String camporeeType,
    String? clubName,
    int? insuranceId,
  }) async {
    try {
      final model = await remoteDataSource.registerMember(
        camporeeId,
        userId: userId,
        camporeeType: camporeeType,
        clubName: clubName,
        insuranceId: insuranceId,
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
  Future<Either<Failure, List<CamporeeMember>>> getCamporeeMembers(
      int camporeeId, {CancelToken? cancelToken}) async {
    try {
      final models = await remoteDataSource.getCamporeeMembers(camporeeId, cancelToken: cancelToken);
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
  Future<Either<Failure, void>> removeMember(
      int camporeeId, String userId) async {
    try {
      await remoteDataSource.removeMember(camporeeId, userId);
      return const Right(null);
    } on ServerException catch (e) {
      return _serverFailure(e);
    } on AuthException catch (e) {
      return _authFailure(e);
    } catch (e) {
      return _unexpectedFailure(e);
    }
  }

  // ── Payments ────────────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, CamporeeEnrolledClub>> enrollClub(
    int camporeeId, {
    required int clubSectionId,
  }) async {
    try {
      final model = await remoteDataSource.enrollClub(
        camporeeId,
        clubSectionId: clubSectionId,
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
  Future<Either<Failure, List<CamporeeEnrolledClub>>> getEnrolledClubs(
      int camporeeId, {CancelToken? cancelToken}) async {
    try {
      final models = await remoteDataSource.getEnrolledClubs(camporeeId, cancelToken: cancelToken);
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
  Future<Either<Failure, CamporeePayment>> createPayment(
    int camporeeId,
    String memberId, {
    required double amount,
    required String paymentType,
    String? reference,
    DateTime? paymentDate,
    String? notes,
  }) async {
    try {
      final model = await remoteDataSource.createPayment(
        camporeeId,
        memberId,
        amount: amount,
        paymentType: paymentType,
        reference: reference,
        paymentDate: paymentDate,
        notes: notes,
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
  Future<Either<Failure, List<CamporeePayment>>> getMemberPayments(
    int camporeeId,
    String memberId, {
    CancelToken? cancelToken,
  }) async {
    try {
      final models =
          await remoteDataSource.getMemberPayments(camporeeId, memberId, cancelToken: cancelToken);
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
  Future<Either<Failure, List<CamporeePayment>>> getCamporeePayments(
      int camporeeId, {CancelToken? cancelToken}) async {
    try {
      final models = await remoteDataSource.getCamporeePayments(camporeeId, cancelToken: cancelToken);
      return Right(models.map((m) => m.toEntity()).toList());
    } on ServerException catch (e) {
      return _serverFailure(e);
    } on AuthException catch (e) {
      return _authFailure(e);
    } catch (e) {
      return _unexpectedFailure(e);
    }
  }
}
