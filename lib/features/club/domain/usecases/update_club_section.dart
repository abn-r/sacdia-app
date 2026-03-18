import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/club_info.dart';
import '../repositories/club_repository.dart';

/// Parámetros para [UpdateClubSection].
class UpdateClubSectionParams {
  final String clubId;
  final int sectionId;

  // Campos editables — solo los no-null son enviados
  final String? name;
  final String? phone;
  final String? email;
  final String? website;
  final String? logoUrl;
  final String? address;
  final double? lat;
  final double? long;

  const UpdateClubSectionParams({
    required this.clubId,
    required this.sectionId,
    this.name,
    this.phone,
    this.email,
    this.website,
    this.logoUrl,
    this.address,
    this.lat,
    this.long,
  });
}

/// Caso de uso: actualiza los datos editables de una sección de club.
class UpdateClubSection
    implements UseCase<ClubSection, UpdateClubSectionParams> {
  final ClubRepository _repository;

  const UpdateClubSection(this._repository);

  @override
  Future<Either<Failure, ClubSection>> call(UpdateClubSectionParams params) {
    return _repository.updateClubSection(
      clubId: params.clubId,
      sectionId: params.sectionId,
      name: params.name,
      phone: params.phone,
      email: params.email,
      website: params.website,
      logoUrl: params.logoUrl,
      address: params.address,
      lat: params.lat,
      long: params.long,
    );
  }
}
