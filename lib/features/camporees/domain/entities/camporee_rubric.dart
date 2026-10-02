import 'package:equatable/equatable.dart';

/// Criterio de rúbrica para puntuar un evento de camporí.
class CamporeeRubric extends Equatable {
  final int rubricId;
  final int eventId;
  final String title;
  final String? description;
  final double maxPoints;
  final int displayOrder;
  final bool active;

  const CamporeeRubric({
    required this.rubricId,
    required this.eventId,
    required this.title,
    this.description,
    required this.maxPoints,
    required this.displayOrder,
    required this.active,
  });

  @override
  List<Object?> get props => [
        rubricId,
        eventId,
        title,
        description,
        maxPoints,
        displayOrder,
        active,
      ];
}

/// Rúbricas activas de un evento y el piso de puntaje del evento.
class CamporeeEventRubricSheet extends Equatable {
  final List<CamporeeRubric> rubrics;
  final double minPoints;

  const CamporeeEventRubricSheet({
    required this.rubrics,
    this.minPoints = 0,
  });

  /// Misma regla que el backend: si el mínimo es mayor que cero y la suma
  /// cruda queda debajo, el total oficial sube a ese piso.
  double officialTotal(double raw) {
    if (minPoints > 0 && raw < minPoints) return minPoints;
    return raw;
  }

  @override
  List<Object?> get props => [rubrics, minPoints];
}
