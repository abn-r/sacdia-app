/// Decisión final de la unión sobre una sección de evidencias.
///
/// El servidor es la fuente de verdad — este enum refleja los valores del
/// campo `union_decision` en `annual_folder_section_evaluations`.
///
/// Valores del backend:
///   APPROVED | REJECTED_OVERRIDE
enum UnionEvaluationDecision {
  /// La unión aprobó la sección. Valor backend: `APPROVED`.
  approved,

  /// La unión rechazó una sección que había sido pre-aprobada por el campo
  /// local. Valor backend: `REJECTED_OVERRIDE`.
  rejectedOverride,
}

extension UnionEvaluationDecisionX on UnionEvaluationDecision {
  /// Deserializa el string exacto que llega desde el backend.
  ///
  /// Retorna null si el valor es desconocido o nulo.
  static UnionEvaluationDecision? fromJson(String? value) {
    switch (value?.toUpperCase()) {
      case 'APPROVED':
        return UnionEvaluationDecision.approved;
      case 'REJECTED_OVERRIDE':
        return UnionEvaluationDecision.rejectedOverride;
      default:
        return null;
    }
  }

  /// Serializa al string canónico del backend.
  String toJson() {
    switch (this) {
      case UnionEvaluationDecision.approved:
        return 'APPROVED';
      case UnionEvaluationDecision.rejectedOverride:
        return 'REJECTED_OVERRIDE';
    }
  }
}
