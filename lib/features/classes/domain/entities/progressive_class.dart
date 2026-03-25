import 'package:equatable/equatable.dart';

/// Entidad de clase progresiva del dominio
class ProgressiveClass extends Equatable {
  final int id;
  final String name;
  final String? description;
  final int clubTypeId;
  final String? imageUrl;

  /// Estado de investidura proveniente del enrollment.
  /// Valores posibles: null (no inscripto), 'PENDIENTE', 'INVESTIDO', etc.
  final String? investitureStatus;

  /// Progreso general de 0 a 100, proveniente del enrollment.
  final int? overallProgress;

  const ProgressiveClass({
    required this.id,
    required this.name,
    this.description,
    required this.clubTypeId,
    this.imageUrl,
    this.investitureStatus,
    this.overallProgress,
  });

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        clubTypeId,
        imageUrl,
        investitureStatus,
        overallProgress,
      ];
}
