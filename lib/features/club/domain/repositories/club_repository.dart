import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/club_info.dart';

/// Contrato del repositorio para el módulo de club.
abstract class ClubRepository {
  /// Obtiene el detalle del club contenedor por su UUID.
  Future<Either<Failure, ClubInfo>> getClub(String clubId);

  /// Obtiene la sección de club por ID.
  Future<Either<Failure, ClubSection>> getClubSection({
    required String clubId,
    required int sectionId,
  });

  /// Actualiza la sección de club.
  ///
  /// Solo los campos no-null son enviados al backend (PATCH semántico).
  Future<Either<Failure, ClubSection>> updateClubSection({
    required String clubId,
    required int sectionId,
    String? name,
    String? phone,
    String? email,
    String? website,
    String? logoUrl,
    String? address,
    double? lat,
    double? long,
  });
}
