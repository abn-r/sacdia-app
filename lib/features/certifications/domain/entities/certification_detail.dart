import 'package:equatable/equatable.dart';
import 'certification_module.dart';

/// Entidad de detalle de certificación del dominio (incluye módulos y secciones)
class CertificationDetail extends Equatable {
  final int certificationId;
  final String name;
  final String? description;
  final bool active;
  final int modulesCount;
  final List<CertificationModule> modules;

  const CertificationDetail({
    required this.certificationId,
    required this.name,
    this.description,
    required this.active,
    required this.modulesCount,
    this.modules = const [],
  });

  @override
  List<Object?> get props => [
        certificationId,
        name,
        description,
        active,
        modulesCount,
        modules,
      ];
}
