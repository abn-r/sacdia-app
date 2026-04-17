import '../../domain/entities/evidence_section.dart';
import '../../domain/entities/union_evaluation_decision.dart';
import 'evidence_file_model.dart';

/// Modelo de datos para [EvidenceSection].
///
/// Mapea la respuesta JSON del módulo AnnualFolders al dominio.
/// Campos AnnualFolders:
///   section_id, name, description, order, required,
///   max_points, minimum_points, evidences (array),
///   evidence_count, evaluation (object|null), status (stored enum).
///
/// A partir del rework annual-folders-ownership-rework, el campo [status]
/// se lee directamente del JSON (columna STORED en Postgres). Ya no se
/// deriva en el cliente.
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
    super.lfApproverName,
    super.lfApprovedAt,
    super.unionApproverName,
    super.unionApprovedAt,
    super.unionDecision,
  });

  factory EvidenceSectionModel.fromJson(Map<String, dynamic> json) {
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

    // ── Status almacenado (fuente de verdad: servidor) ──────────────────────
    // Se lee el campo `status` del JSON directamente. Si el campo no está
    // presente (rollout parcial), se usa PENDING como fallback seguro.
    final storedStatus =
        EvidenceSectionStatusX.fromJson(json['status']?.toString());

    // ── Actores de aprobación dual-level ────────────────────────────────────
    final lfApproverName =
        (json['lf_approver'] ?? json['lfApprover'])?.toString();
    final lfApprovedAt = _parseDate(
        (json['lf_approved_at'] ?? json['lfApprovedAt'])?.toString());

    final unionApproverName =
        (json['union_approver'] ?? json['unionApprover'])?.toString();
    final unionApprovedAt = _parseDate(
        (json['union_approved_at'] ?? json['unionApprovedAt'])?.toString());

    final unionDecision = UnionEvaluationDecisionX.fromJson(
        (json['union_decision'] ?? json['unionDecision'])?.toString());

    return EvidenceSectionModel(
      // AnnualFolders usa section_id; fallback a id/section_id legacy
      id: (json['section_id'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? json['section_name'] ?? '').toString(),
      description: json['description']?.toString(),
      // AnnualFolders usa max_points para el valor en puntos de la sección
      pointValue: _parseInt(
          json['max_points'] ?? json['point_value'] ?? json['pointValue'] ?? 0),
      // percentage no existe en AnnualFolders — se mantiene en 0.0 si no viene
      percentage:
          _parseDouble(json['percentage'] ?? json['weight_percentage'] ?? 0.0),
      // max_files no existe en AnnualFolders, usamos el default 10
      maxFiles: _parseInt(json['max_files'] ?? json['maxFiles'] ?? 10),
      status: storedStatus,
      files: files,
      submittedByName: (submission?['submitted_by'] ??
              json['submitted_by_name'] ??
              json['submittedByName'])
          ?.toString(),
      submittedAt: _parseDate(submission?['submitted_at']?.toString() ??
          json['submitted_at']?.toString() ??
          json['submittedAt']?.toString()),
      validatedByName:
          (json['validated_by_name'] ?? json['validatedByName'])?.toString(),
      validatedAt: _parseDate(
          json['validated_at']?.toString() ?? json['validatedAt']?.toString()),
      earnedPoints: earnedPoints,
      evaluatedByName: evaluatedByName,
      evaluatedAt: evaluatedAt,
      evaluationNotes: evaluationNotes,
      lfApproverName: lfApproverName,
      lfApprovedAt: lfApprovedAt,
      unionApproverName: unionApproverName,
      unionApprovedAt: unionApprovedAt,
      unionDecision: unionDecision,
    );
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
        lfApproverName: lfApproverName,
        lfApprovedAt: lfApprovedAt,
        unionApproverName: unionApproverName,
        unionApprovedAt: unionApprovedAt,
        unionDecision: unionDecision,
      );
}
