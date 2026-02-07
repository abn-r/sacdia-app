import 'package:equatable/equatable.dart';
import 'class_section.dart';

/// Entidad de módulo de clase del dominio
class ClassModule extends Equatable {
  final int id;
  final String name;
  final int classId;
  final List<ClassSection> sections;

  const ClassModule({
    required this.id,
    required this.name,
    required this.classId,
    required this.sections,
  });

  @override
  List<Object?> get props => [id, name, classId, sections];
}
