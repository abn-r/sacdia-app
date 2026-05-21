import '../../domain/entities/class_with_progress.dart';
import 'class_module_detail_model.dart';
import '../../../../core/utils/json_helpers.dart';

/// Modelo de datos para [ClassWithProgress].
class ClassWithProgressModel extends ClassWithProgress {
  const ClassWithProgressModel({
    required super.id,
    required super.name,
    super.description,
    required super.clubTypeId,
    super.imageUrl,
    super.investitureStatus,
    super.availableFromYearId,
    super.availableUntilYearId,
    super.minDurationYears,
    super.maxDurationYears,
    super.modules,
  });

  factory ClassWithProgressModel.fromJson(Map<String, dynamic> json) {
    final rawModules = json['modules'] as List<dynamic>? ?? [];

    final modules = rawModules
        .map((m) => ClassModuleDetailModel.fromJson(m as Map<String, dynamic>)
            .toEntity())
        .toList();

    return ClassWithProgressModel(
      id: safeInt(json['class_id'] ?? json['id']),
      name: safeString(json['name'], 'Clase'),
      description: json['description']?.toString(),
      clubTypeId: safeInt(json['club_type_id'] ?? json['clubTypeId']),
      imageUrl: json['image_url']?.toString() ?? json['imageUrl']?.toString(),
      investitureStatus: json['investiture_status']?.toString() ??
          json['investitureStatus']?.toString(),
      availableFromYearId: safeIntOrNull(
          json['available_from_year_id'] ?? json['availableFromYearId']),
      availableUntilYearId: safeIntOrNull(
          json['available_until_year_id'] ?? json['availableUntilYearId']),
      minDurationYears:
          safeInt(json['min_duration_years'] ?? json['minDurationYears'], 1),
      maxDurationYears:
          safeInt(json['max_duration_years'] ?? json['maxDurationYears'], 1),
      modules: modules,
    );
  }

  ClassWithProgress toEntity() => ClassWithProgress(
        id: id,
        name: name,
        description: description,
        clubTypeId: clubTypeId,
        imageUrl: imageUrl,
        investitureStatus: investitureStatus,
        availableFromYearId: availableFromYearId,
        availableUntilYearId: availableUntilYearId,
        minDurationYears: minDurationYears,
        maxDurationYears: maxDurationYears,
        modules: modules,
      );
}
