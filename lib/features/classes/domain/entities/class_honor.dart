import 'package:equatable/equatable.dart';

/// Tipo de relación entre una clase y una especialidad (`class_honors`).
///
/// En esta fase todas las relaciones son informativas: incluso `required`
/// no bloquea la investidura de la clase ni el progreso del módulo.
enum ClassHonorRelationType { required, recommended, elective }

ClassHonorRelationType classHonorRelationTypeFromApi(String? value) {
  switch (value?.trim().toUpperCase()) {
    case 'REQUIRED':
      return ClassHonorRelationType.required;
    case 'ELECTIVE':
      return ClassHonorRelationType.elective;
    case 'RECOMMENDED':
    default:
      return ClassHonorRelationType.recommended;
  }
}

extension ClassHonorRelationTypeLabel on ClassHonorRelationType {
  String get label {
    switch (this) {
      case ClassHonorRelationType.required:
        return 'Requerida';
      case ClassHonorRelationType.elective:
        return 'Electiva';
      case ClassHonorRelationType.recommended:
        return 'Recomendada';
    }
  }
}

/// Entidad de especialidad recomendada/relacionada a una clase progresiva.
///
/// Proviene de `GET /classes/:classId/honors`, que expone la tabla
/// `class_honors` con el estado opcional del usuario autenticado.
class ClassHonor extends Equatable {
  final int classHonorId;
  final ClassHonorRelationType relationType;
  final int honorId;
  final String honorName;
  final String? honorImage;
  final int? honorCategoryId;
  final int? honorSkillLevel;

  /// Módulo ancla (`class_honors.module_id`). Null = nivel de clase.
  final int? moduleId;
  final String? moduleName;

  /// PDF público del catálogo (`honors.material_url`).
  final String? materialUrl;

  /// Estado de validación del usuario para esta especialidad
  /// (`users_honors.validation_status`), null si no está autenticado o no
  /// ha iniciado la especialidad.
  final String? userStatus;

  const ClassHonor({
    required this.classHonorId,
    required this.relationType,
    required this.honorId,
    required this.honorName,
    this.honorImage,
    this.honorCategoryId,
    this.honorSkillLevel,
    this.moduleId,
    this.moduleName,
    this.materialUrl,
    this.userStatus,
  });

  /// Si el usuario ya validó/completó esta especialidad.
  bool get isCompletedByUser => userStatus?.trim().toUpperCase() == 'APPROVED';

  bool get hasMaterial {
    final url = materialUrl?.trim();
    return url != null && url.isNotEmpty;
  }

  bool get isEnrolled {
    final status = userStatus?.trim();
    return status != null && status.isNotEmpty;
  }

  @override
  List<Object?> get props => [
        classHonorId,
        relationType,
        honorId,
        honorName,
        honorImage,
        honorCategoryId,
        honorSkillLevel,
        moduleId,
        moduleName,
        materialUrl,
        userStatus,
      ];
}
