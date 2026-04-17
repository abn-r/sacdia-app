import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/club_info.dart';
import '../repositories/club_repository.dart';

/// Parámetros para [GetClubInfo].
class GetClubInfoParams {
  final String clubId;

  const GetClubInfoParams({required this.clubId});
}

/// Caso de uso: obtiene la información básica del club contenedor.
class GetClubInfo implements UseCase<ClubInfo, GetClubInfoParams> {
  final ClubRepository _repository;

  const GetClubInfo(this._repository);

  @override
  Future<Either<Failure, ClubInfo>> call(GetClubInfoParams params, {CancelToken? cancelToken}) {
    return _repository.getClub(params.clubId, cancelToken: cancelToken);
  }
}
