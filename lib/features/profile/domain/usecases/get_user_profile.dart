import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/user_detail.dart';
import '../repositories/profile_repository.dart';

/// Parámetros para obtener el perfil del usuario
class GetUserProfileParams {
  final String userId;

  const GetUserProfileParams({required this.userId});
}

/// Caso de uso para obtener el perfil del usuario
class GetUserProfile implements UseCase<UserDetail, GetUserProfileParams> {
  final ProfileRepository repository;

  GetUserProfile(this.repository);

  @override
  Future<Either<Failure, UserDetail>> call(GetUserProfileParams params) async {
    return await repository.getUserProfile(params.userId);
  }
}
