import 'package:equatable/equatable.dart';
import 'certification_section.dart';

/// Entidad de módulo de certificación del dominio
class CertificationModule extends Equatable {
  final int moduleId;
  final String name;
  final String? description;
  final List<CertificationSection> sections;

  const CertificationModule({
    required this.moduleId,
    required this.name,
    this.description,
    this.sections = const [],
  });

  @override
  List<Object?> get props => [moduleId, name, description, sections];
}
