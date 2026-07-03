import 'package:equatable/equatable.dart';

/// Ítem enviado para puntuar un criterio de rúbrica.
class CamporeeScoreSubmissionItem extends Equatable {
  final int rubricId;
  final double awardedPoints;
  final String? notes;

  const CamporeeScoreSubmissionItem({
    required this.rubricId,
    required this.awardedPoints,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
        'camporee_event_rubric_id': rubricId,
        'awarded_points': awardedPoints,
        if (notes != null && notes!.trim().isNotEmpty) 'notes': notes,
      };

  @override
  List<Object?> get props => [rubricId, awardedPoints, notes];
}

/// Submission oficial de puntaje por evento/sección.
class CamporeeScoreSubmission extends Equatable {
  final String source;
  final String? notes;
  final List<CamporeeScoreSubmissionItem> items;

  const CamporeeScoreSubmission({
    this.source = 'judge_primary',
    this.notes,
    required this.items,
  });

  Map<String, dynamic> toJson() => {
        'source': source,
        if (notes != null && notes!.trim().isNotEmpty) 'notes': notes,
        'items': items.map((item) => item.toJson()).toList(),
      };

  @override
  List<Object?> get props => [source, notes, items];
}
