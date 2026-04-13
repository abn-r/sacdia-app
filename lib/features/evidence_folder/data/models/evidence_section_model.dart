import '../../domain/entities/evidence_section.dart';
import 'evidence_file_model.dart';

/// Modelo de datos para [EvidenceSection].
///
/// Mapea la respuesta JSON del módulo AnnualFolders al dominio.
/// Campos AnnualFolders:
///   section_id, name, description, order, required,
///   max_points, minimum_points, evidences (array),
///   evidence_count, evaluation (object|null).
///
/// El campo [status] se deriva del folder status + presencia de evaluation,
/// ya que AnnualFolders no expone un status por sección.
class EvidenceSectionModel extends EvidenceSection {
  const EvidenceSectionModel({
    required super.id,
    required super.name,
    super.description,
    required super.pointValue,
    required super.percentage,
    super.maxFiles,
    required super.status,
    super.files,
    super.submittedByName,
    super.submittedAt,
    super.validatedByName,
    super.validatedAt,
    super.earnedPoints,
    super.evaluatedByName,
    super.evaluatedAt,
    super.evaluationNotes,
  });

  factory EvidenceSectionModel.fromJson(
    Map<String, dynamic> json, {
    /// Estado de la carpeta padre, necesario para derivar el status de sección.
    String? folderStatus,
  }) {
    // ── Evidencias ──────────────────────────────────────────────────────────
    // AnnualFolders usa 'evidences'; fallback a claves legacy
    final rawFiles = json['evidences'] as List<dynamic>? ??
        json['files'] as List<dynamic>? ??
        json['evidence_files'] as List<dynamic>? ??
        [];

    final files = rawFiles
        .map((f) => EvidenceFileModel.fromJson(f as Map<String, dynamic>))
        .toList();

    // ── Evaluación ──────────────────────────────────────────────────────────
    final evaluation = json['evaluation'] as Map<String, dynamic>?;

    final earnedPoints = evaluation != null
        ? _parseInt(evaluation['earned_points'] ??
            evaluation['earnedPoints'] ??
            json['earned_points'] ??
            json['earnedPoints'] ??
            0)
        : _parseInt(json['earned_points'] ?? json['earnedPoints'] ?? 0);

    // Backend sends 'evaluator' (formatted name), fallback to legacy keys
    final evaluatedByName = (evaluation?['evaluator'] ??
            evaluation?['evaluated_by'] ??
            evaluation?['evaluatedBy'] ??
            json['evaluated_by_name'] ??
            json['evaluatedByName'])
        ?.toString();

    final evaluatedAt = _parseDate(
      (evaluation?['evaluated_at'] ?? evaluation?['evaluatedAt'])?.toString() ??
          json['evaluated_at']?.toString() ??
          json['evaluatedAt']?.toString(),
    );

    // ── Submission por sección ──────────────────────────────────────────────
    final submission = json['submission'] as Map<String, dynamic>?;

    final evaluationNotes = (evaluation?['notes'] ??
            json['evaluation_notes'] ??
            json['evaluationNotes'])
        ?.toString();

    // ── Status derivado ─────────────────────────────────────────────────────
    // Prioridad:
    //  1. Si hay evaluation -> evaluated
    //  2. submission_status == 'submitted' (campo por sección del nuevo endpoint)
    //  3. Campo legacy string 'status' en el JSON de la sección
    //  4. Derivado desde folder status (backward compat)
    //  5. Default -> pendiente
    final derivedStatus = _deriveStatus(
      jsonStatus: json['status']?.toString(),
      submissionStatus: json['submission_status']?.toString(),
      folderStatus: folderStatus,
      hasEvaluation: evaluation != null,
    );

    return EvidenceSectionModel(
      // AnnualFolders usa section_id; fallback a id/section_id legacy
      id: (json['section_id'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? json['section_name'] ?? '').toString(),
      description: json['description']?.toString(),
      // AnnualFolders usa max_points para el valor en puntos de la sección
      pointValue: _parseInt(
          json['max_points'] ?? json['point_value'] ?? json['pointValue'] ?? 0),
      // percentage no existe en AnnualFolders — se mantiene en 0.0 si no viene
      percentage: _parseDouble(
          json['percentage'] ?? json['weight_percentage'] ?? 0.0),
      // max_files no existe en AnnualFolders, usamos el default 10
      maxFiles: _parseInt(json['max_files'] ?? json['maxFiles'] ?? 10),
      status: derivedStatus,
      files: files,
      submittedByName: (submission?['submitted_by'] ??
              json['submitted_by_name'] ??
              json['submittedByName'])
          ?.toString(),
      submittedAt: _parseDate(
          submission?['submitted_at']?.toString() ??
          json['submitted_at']?.toString() ??
          json['submittedAt']?.toString()),
      validatedByName: (json['validated_by_name'] ??
              json['validatedByName'])
          ?.toString(),
      validatedAt: _parseDate(
          json['validated_at']?.toString() ?? json['validatedAt']?.toString()),
      earnedPoints: earnedPoints,
      evaluatedByName: evaluatedByName,
      evaluatedAt: evaluatedAt,
      evaluationNotes: evaluationNotes,
    );
  }

  // ── Status derivation ────────────────────────────────────────────────────────

  static EvidenceSectionStatus _deriveStatus({
    required String? jsonStatus,
    required String? submissionStatus,
    required String? folderStatus,
    required bool hasEvaluation,
  }) {
    // 1. Si la sección tiene evaluación asignada, está evaluated
    if (hasEvaluation) return EvidenceSectionStatus.evaluated;

    // 2. submission_status a nivel de sección (campo nuevo del backend)
    if (submissionStatus != null && submissionStatus.isNotEmpty) {
      if (submissionStatus == 'submitted') {
        return EvidenceSectionStatus.enviado;
      }
      // 'pending' con folderStatus 'submitted' → backward compat:
      // si la carpeta entera fue enviada, la sección también está enviada
      if (submissionStatus == 'pending' &&
          folderStatus?.toLowerCase() == 'submitted') {
        return EvidenceSectionStatus.enviado;
      }
    }

    // 3. Si hay un status explícito en el JSON de la sección (legacy), usarlo
    if (jsonStatus != null && jsonStatus.isNotEmpty) {
      return evidenceSectionStatusFromString(jsonStatus);
    }

    // 4. Derivar desde el status de la carpeta padre (backward compat)
    switch (folderStatus?.toLowerCase()) {
      case 'submitted':
        return EvidenceSectionStatus.enviado;
      case 'under_evaluation':
        return EvidenceSectionStatus.underEvaluation;
      case 'evaluated':
      case 'closed':
        return EvidenceSectionStatus.evaluated;
      default:
        return EvidenceSectionStatus.pendiente;
    }
  }

  // ── Parse helpers ─────────────────────────────────────────────────────────────

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static double _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  EvidenceSection toEntity() => EvidenceSection(
        id: id,
        name: name,
        description: description,
        pointValue: pointValue,
        percentage: percentage,
        maxFiles: maxFiles,
        status: status,
        files: files,
        submittedByName: submittedByName,
        submittedAt: submittedAt,
        validatedByName: validatedByName,
        validatedAt: validatedAt,
        earnedPoints: earnedPoints,
        evaluatedByName: evaluatedByName,
        evaluatedAt: evaluatedAt,
        evaluationNotes: evaluationNotes,
      );
}
