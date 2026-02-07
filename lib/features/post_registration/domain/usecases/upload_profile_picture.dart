import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/post_registration_repository.dart';

/// Caso de uso para subir la foto de perfil
class UploadProfilePicture implements UseCase<String, UploadProfilePictureParams> {
  final PostRegistrationRepository repository;

  UploadProfilePicture(this.repository);

  @override
  Future<Either<Failure, String>> call(UploadProfilePictureParams params) {
    return repository.uploadProfilePicture(
      userId: params.userId,
      filePath: params.filePath,
    );
  }
}

/// Parámetros para subir foto de perfil
class UploadProfilePictureParams extends Equatable {
  final String userId;
  final String filePath;

  const UploadProfilePictureParams({
    required this.userId,
    required this.filePath,
  });

  @override
  List<Object> get props => [userId, filePath];
}
