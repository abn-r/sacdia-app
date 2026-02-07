import 'package:equatable/equatable.dart';

/// Entidad que representa el estado de completitud del post-registro
class CompletionStatus extends Equatable {
  /// Indica si el post-registro está completo
  final bool isComplete;

  /// Paso actual del post-registro (1, 2 o 3)
  final int currentStep;

  /// Indica si el paso 1 (foto) está completo
  final bool photoComplete;

  /// Indica si el paso 2 (info personal) está completo
  final bool personalInfoComplete;

  /// Indica si el paso 3 (selección de club) está completo
  final bool clubSelectionComplete;

  const CompletionStatus({
    required this.isComplete,
    required this.currentStep,
    required this.photoComplete,
    required this.personalInfoComplete,
    required this.clubSelectionComplete,
  });

  @override
  List<Object?> get props => [
        isComplete,
        currentStep,
        photoComplete,
        personalInfoComplete,
        clubSelectionComplete,
      ];
}
