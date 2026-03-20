import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/camporee.dart';
import '../entities/camporee_member.dart';

/// Repositorio de camporees (interfaz del dominio)
abstract class CamporeesRepository {
  /// Obtiene la lista de camporees. Opcionalmente filtra por activos.
  Future<Either<Failure, List<Camporee>>> getCamporees({bool? active});

  /// Obtiene el detalle de un camporee por ID.
  Future<Either<Failure, Camporee>> getCamporeeDetail(int camporeeId);

  /// Registra un miembro en un camporee.
  Future<Either<Failure, CamporeeMember>> registerMember(
    int camporeeId, {
    required String userId,
    required String camporeeType,
    String? clubName,
    int? insuranceId,
  });

  /// Obtiene los miembros inscritos en un camporee.
  Future<Either<Failure, List<CamporeeMember>>> getCamporeeMembers(
      int camporeeId);

  /// Remueve un miembro de un camporee.
  Future<Either<Failure, void>> removeMember(int camporeeId, String userId);
}
