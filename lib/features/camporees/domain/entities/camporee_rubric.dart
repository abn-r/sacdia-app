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
