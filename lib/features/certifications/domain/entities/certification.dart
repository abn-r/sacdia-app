import 'package:equatable/equatable.dart';

/// Entidad de certificación del dominio
class Certification extends Equatable {
  final int certificationId;
  final String name;
  final String? description;
  final bool active;
  final int modulesCount;

  /// Total de requisitos; nulo cuando el backend no lo envía en el catálogo.
  final int? requirementsCount;

  const Certification({
    required this.certificationId,
    required this.name,
    this.description,
    required this.active,
    required this.modulesCount,
    this.requirementsCount,
  });

  @override
  List<Object?> get props => [
        certificationId,
        name,
        description,
        active,
        modulesCount,
        requirementsCount,
      ];
}
