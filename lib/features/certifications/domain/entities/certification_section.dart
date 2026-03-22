import 'package:equatable/equatable.dart';

/// Entidad de sección de módulo de certificación del dominio
class CertificationSection extends Equatable {
  final int sectionId;
  final String name;
  final String? description;

  const CertificationSection({
    required this.sectionId,
    required this.name,
    this.description,
  });

  @override
  List<Object?> get props => [sectionId, name, description];
}
