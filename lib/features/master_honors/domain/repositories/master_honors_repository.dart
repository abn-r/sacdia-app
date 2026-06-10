import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import '../../../../core/errors/failures.dart';
import '../entities/master_honor_roadmap.dart';
import '../entities/user_master_honor.dart';

abstract class MasterHonorsRepository {
  Future<Either<Failure, List<UserMasterHonor>>> getUserMasterHonors(
    String userId, {
    CancelToken? cancelToken,
  });

  Future<Either<Failure, List<MasterHonorRoadmap>>> getUserMasterHonorRoadmap(
    String userId, {
    CancelToken? cancelToken,
  });
}
