import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/user_master_honor.dart';
import '../../domain/repositories/master_honors_repository.dart';
import '../datasources/master_honors_remote_data_source.dart';

class MasterHonorsRepositoryImpl implements MasterHonorsRepository {
  final MasterHonorsRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  MasterHonorsRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, List<UserMasterHonor>>> getUserMasterHonors(
    String userId, {
    CancelToken? cancelToken,
  }) async {
    try {
      final models = await remoteDataSource.getUserMasterHonors(
        userId,
        cancelToken: cancelToken,
      );
      return Right(models.map((model) => model.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }
}
