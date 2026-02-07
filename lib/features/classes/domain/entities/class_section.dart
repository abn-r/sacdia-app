import 'package:equatable/equatable.dart';

/// Entidad de sección de clase del dominio
class ClassSection extends Equatable {
  final int id;
  final String name;
  final int moduleId;
  final bool isCompleted;

  const ClassSection({
    required this.id,
    required this.name,
    required this.moduleId,
    this.isCompleted = false,
  });

  @override
  List<Object?> get props => [id, name, moduleId, isCompleted];
}
