import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/post_registration_repository.dart';

/// Caso de uso para eliminar la foto de perfil
class DeleteProfilePicture implements UseCase<void, DeleteProfilePictureParams> {
  final PostRegistrationRepository repository;

  DeleteProfilePicture(this.repository);

  @override
  Future<Either<Failure, void>> call(DeleteProfilePictureParams params) {
    return repository.deleteProfilePicture(userId: params.userId);
  }
}

/// Parámetros para eliminar foto de perfil
class DeleteProfilePictureParams extends Equatable {
  final String userId;

  const DeleteProfilePictureParams({required this.userId});

  @override
  List<Object> get props => [userId];
}
