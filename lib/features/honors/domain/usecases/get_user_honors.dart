import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/user_honor.dart';
import '../repositories/honors_repository.dart';

/// Caso de uso para obtener las especialidades de un usuario
class GetUserHonors implements UseCase<List<UserHonor>, GetUserHonorsParams> {
  final HonorsRepository repository;

  GetUserHonors(this.repository);

  @override
  Future<Either<Failure, List<UserHonor>>> call(GetUserHonorsParams params) async {
    return await repository.getUserHonors(params.userId);
  }
}

/// Parámetros para obtener las especialidades de un usuario
class GetUserHonorsParams {
  final String userId;

  const GetUserHonorsParams({required this.userId});
}
