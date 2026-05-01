import 'package:equatable/equatable.dart';

/// Entidad de clase progresiva del dominio
class ProgressiveClass extends Equatable {
  final int id;
  final String name;
  final String? description;
  final int clubTypeId;
  final String? imageUrl;

  /// Estado de investidura proveniente del enrollment.
  /// Valores posibles: null (no inscrito), 'PENDIENTE', 'INVESTIDO', etc.
  final String? investitureStatus;

  /// Progreso general de 0 a 100, proveniente del enrollment.
  final int? overallProgress;

  /// Código de asset local para el roadmap (e.g. "AV-01", "CQ-03").
  /// Cuando está presente, se usa para resolver directamente el asset local
  /// en lugar de inferirlo por posición ordinal.
  /// Null hasta que el backend esté desplegado con el campo poblado.
  final String? assetCode;

  const ProgressiveClass({
    required this.id,
    required this.name,
    this.description,
    required this.clubTypeId,
    this.imageUrl,
    this.investitureStatus,
    this.overallProgress,
    this.assetCode,
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
        assetCode,
      ];
}
