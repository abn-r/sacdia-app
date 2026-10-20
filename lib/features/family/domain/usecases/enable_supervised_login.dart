import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/supervised_login.dart';
import '../repositories/family_repository.dart';

class EnableSupervisedLoginParams extends Equatable {
  final String dependentId;
  final SupervisedLoginMethod method;
  final String password;

  /// Solo con el método `email`.
  final String? email;

  const EnableSupervisedLoginParams({
    required this.dependentId,
    required this.method,
    required this.password,
    this.email,
  });

  /// Sin la contraseña: este objeto puede acabar en un log de pruebas.
  @override
  List<Object?> get props => [dependentId, method, email];
}

/// `POST /guardianships/me/dependents/:id/supervised-login`.
class EnableSupervisedLogin
    implements UseCase<EnabledSupervisedLogin, EnableSupervisedLoginParams> {
  final FamilyRepository repository;

  EnableSupervisedLogin(this.repository);

  @override
  Future<Either<Failure, EnabledSupervisedLogin>> call(
    EnableSupervisedLoginParams params,
  ) =>
      repository.enableSupervisedLogin(
        dependentId: params.dependentId,
        method: params.method,
        password: params.password,
        email: params.email,
      );
}
