import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/club_info.dart';
import '../../domain/repositories/club_repository.dart';
import '../datasources/club_remote_data_source.dart';

/// Implementación de [ClubRepository].
class ClubRepositoryImpl implements ClubRepository {
  final ClubRemoteDataSource _remoteDataSource;
  final NetworkInfo _networkInfo;

  const ClubRepositoryImpl({
    required ClubRemoteDataSource remoteDataSource,
    required NetworkInfo networkInfo,
  })  : _remoteDataSource = remoteDataSource,
        _networkInfo = networkInfo;

  // ── getClub ───────────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, ClubInfo>> getClub(String clubId, {CancelToken? cancelToken}) async {
    try {
      final model = await _remoteDataSource.getClub(clubId, cancelToken: cancelToken);
      return Right(model);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) rethrow;
      return Left(UnexpectedFailure(message: e.toString()));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  // ── getClubSection ────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, ClubSection>> getClubSection({
    required String clubId,
    required int sectionId,
    CancelToken? cancelToken,
  }) async {
    try {
      final model = await _remoteDataSource.getClubSection(
        clubId: clubId,
        sectionId: sectionId,
        cancelToken: cancelToken,
      );
      return Right(model);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) rethrow;
      return Left(UnexpectedFailure(message: e.toString()));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  // ── updateClubSection ─────────────────────────────────────────────────────

  @override
  Future<Either<Failure, ClubSection>> updateClubSection({
    required String clubId,
    required int sectionId,
    String? name,
    String? phone,
    String? email,
    String? website,
    String? logoUrl,
    String? address,
    double? lat,
    double? long,
  }) async {
    // Construir el payload solo con los campos que vienen no-null
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (phone != null) data['phone'] = phone;
    if (email != null) data['email'] = email;
    if (website != null) data['website'] = website;
    if (logoUrl != null) data['logo_url'] = logoUrl;
    if (address != null) data['address'] = address;
    if (lat != null) data['lat'] = lat;
    if (long != null) data['long'] = long;

    try {
      final model = await _remoteDataSource.updateClubSection(
        clubId: clubId,
        sectionId: sectionId,
        data: data,
      );
      return Right(model);
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }
}
