import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/club_info.dart';

/// Contrato del repositorio para el módulo de club.
abstract class ClubRepository {
  /// Obtiene el detalle del club contenedor por su UUID.
  Future<Either<Failure, ClubInfo>> getClub(String clubId);

  /// Obtiene la instancia de club por tipo.
  ///
  /// [clubId] – UUID del club contenedor.
  /// [instanceType] – slug: 'adventurers' | 'pathfinders' | 'master_guild'.
  /// [instanceId] – ID numérico de la instancia.
  Future<Either<Failure, ClubInstance>> getClubInstance({
    required String clubId,
    required String instanceType,
    required int instanceId,
  });

  /// Actualiza la instancia de club.
  ///
  /// Solo los campos no-null son enviados al backend (PATCH semántico).
  Future<Either<Failure, ClubInstance>> updateClubInstance({
    required String clubId,
    required String instanceType,
    required int instanceId,
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
