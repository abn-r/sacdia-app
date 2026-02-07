import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/auth_repository.dart';

/// Caso de uso para solicitar recuperación de contraseña
class ResetPasswordRequest implements UseCase<void, ResetPasswordRequestParams> {
  final AuthRepository repository;

  ResetPasswordRequest(this.repository);

  @override
  Future<Either<Failure, void>> call(ResetPasswordRequestParams params) {
    return repository.resetPassword(params.email);
  }
}

/// Parámetros para el caso de uso ResetPasswordRequest
class ResetPasswordRequestParams extends Equatable {
  final String email;

  const ResetPasswordRequestParams({required this.email});

  @override
  List<Object> get props => [email];
}
