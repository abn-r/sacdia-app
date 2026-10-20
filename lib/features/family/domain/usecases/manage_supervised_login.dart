import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/supervised_login.dart';
import '../repositories/family_repository.dart';

class DisableSupervisedLoginParams extends Equatable {
  final String dependentId;
  final String? reason;

  const DisableSupervisedLoginParams({required this.dependentId, this.reason});

  @override
  List<Object?> get props => [dependentId, reason];
}

/// `POST .../supervised-login/disable`.
class DisableSupervisedLogin
    implements UseCase<SupervisedLoginInfo, DisableSupervisedLoginParams> {
  final FamilyRepository repository;

  DisableSupervisedLogin(this.repository);

  @override
  Future<Either<Failure, SupervisedLoginInfo>> call(
    DisableSupervisedLoginParams params,
  ) =>
      repository.disableSupervisedLogin(
        dependentId: params.dependentId,
        reason: params.reason,
      );
}

class ReactivateSupervisedLoginParams extends Equatable {
  final String dependentId;

  /// Contraseña NUEVA fijada por el tutor (acceso por usuario).
  final String? password;

  const ReactivateSupervisedLoginParams({
    required this.dependentId,
    this.password,
  });

  @override
  List<Object?> get props => [dependentId];
}

/// `POST .../supervised-login/reactivate`.
class ReactivateSupervisedLogin
    implements UseCase<SupervisedLoginInfo, ReactivateSupervisedLoginParams> {
  final FamilyRepository repository;

  ReactivateSupervisedLogin(this.repository);

  @override
  Future<Either<Failure, SupervisedLoginInfo>> call(
    ReactivateSupervisedLoginParams params,
  ) =>
      repository.reactivateSupervisedLogin(
        dependentId: params.dependentId,
        password: params.password,
      );
}

class ResetSupervisedPasswordParams extends Equatable {
  final String dependentId;

  /// Contraseña nueva (acceso por usuario); nula para el de correo.
  final String? password;

  const ResetSupervisedPasswordParams({
    required this.dependentId,
    this.password,
  });

  @override
  List<Object?> get props => [dependentId];
}

/// `POST .../supervised-login/password`.
class ResetSupervisedPassword
    implements UseCase<PasswordResetResult, ResetSupervisedPasswordParams> {
  final FamilyRepository repository;

  ResetSupervisedPassword(this.repository);

  @override
  Future<Either<Failure, PasswordResetResult>> call(
    ResetSupervisedPasswordParams params,
  ) =>
      repository.resetSupervisedPassword(
        dependentId: params.dependentId,
        password: params.password,
      );
}
