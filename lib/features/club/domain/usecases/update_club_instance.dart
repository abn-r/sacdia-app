import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/club_info.dart';
import '../repositories/club_repository.dart';

/// Parámetros para [UpdateClubInstance].
class UpdateClubInstanceParams {
  final String clubId;
  final String instanceType;
  final int instanceId;

  // Campos editables — solo los no-null son enviados
  final String? name;
  final String? phone;
  final String? email;
  final String? website;
  final String? logoUrl;
  final String? address;
  final double? lat;
  final double? long;

  const UpdateClubInstanceParams({
    required this.clubId,
    required this.instanceType,
    required this.instanceId,
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

/// Caso de uso: actualiza los datos editables de una instancia de club.
class UpdateClubInstance
    implements UseCase<ClubInstance, UpdateClubInstanceParams> {
  final ClubRepository _repository;

  const UpdateClubInstance(this._repository);

  @override
  Future<Either<Failure, ClubInstance>> call(UpdateClubInstanceParams params) {
    return _repository.updateClubInstance(
      clubId: params.clubId,
      instanceType: params.instanceType,
      instanceId: params.instanceId,
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
