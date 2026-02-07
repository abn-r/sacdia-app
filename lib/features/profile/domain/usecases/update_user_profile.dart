import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/user_detail.dart';
import '../repositories/profile_repository.dart';

/// Parámetros para actualizar el perfil del usuario
class UpdateUserProfileParams {
  final String userId;
  final Map<String, dynamic> data;

  const UpdateUserProfileParams({
    required this.userId,
    required this.data,
  });
}

/// Caso de uso para actualizar el perfil del usuario
class UpdateUserProfile implements UseCase<UserDetail, UpdateUserProfileParams> {
  final ProfileRepository repository;

  UpdateUserProfile(this.repository);

  @override
  Future<Either<Failure, UserDetail>> call(UpdateUserProfileParams params) async {
    return await repository.updateUserProfile(params.userId, params.data);
  }
}
