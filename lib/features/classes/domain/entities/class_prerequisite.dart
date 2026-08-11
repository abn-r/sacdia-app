import 'package:equatable/equatable.dart';

import '../../../../core/utils/json_helpers.dart';

/// Prerrequisito explícito entre clases progresivas (`class_prerequisites`).
///
/// Representa una clase previa que el usuario debe tener investida
/// (`investiture_status = 'INVESTIDO'`) antes de poder inscribirse en la
/// clase actual.
class ClassPrerequisite extends Equatable {
  final int classId;
  final String name;

  const ClassPrerequisite({
    required this.classId,
    required this.name,
  });

  factory ClassPrerequisite.fromJson(Map<String, dynamic> json) {
    return ClassPrerequisite(
      classId: safeInt(json['class_id'] ?? json['classId']),
      name: safeString(json['name']),
    );
  }

  @override
  List<Object?> get props => [classId, name];
}
