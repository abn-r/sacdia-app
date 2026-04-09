import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/club_info.dart';
import '../repositories/club_repository.dart';

/// Parámetros para [GetClubSection].
class GetClubSectionParams {
  final String clubId;
  final int sectionId;

  const GetClubSectionParams({
    required this.clubId,
    required this.sectionId,
  });
}

/// Caso de uso: obtiene los datos de una sección específica del club.
class GetClubSection implements UseCase<ClubSection, GetClubSectionParams> {
  final ClubRepository _repository;

  const GetClubSection(this._repository);

  @override
  Future<Either<Failure, ClubSection>> call(GetClubSectionParams params, {CancelToken? cancelToken}) {
    return _repository.getClubSection(
      clubId: params.clubId,
      sectionId: params.sectionId,
      cancelToken: cancelToken,
    );
  }
}
