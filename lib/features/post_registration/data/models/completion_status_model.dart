import '../../domain/entities/completion_status.dart';

/// Modelo de datos para el estado de completitud del post-registro
class CompletionStatusModel extends CompletionStatus {
  const CompletionStatusModel({
    required super.isComplete,
    required super.currentStep,
    required super.photoComplete,
    required super.personalInfoComplete,
    required super.clubSelectionComplete,
  });

  /// Crea una instancia desde JSON
  factory CompletionStatusModel.fromJson(Map<String, dynamic> json) {
    final photoComplete = json['photo_complete'] as bool? ?? false;
    final personalInfoComplete = json['personal_info_complete'] as bool? ?? false;
    final clubSelectionComplete = json['club_selection_complete'] as bool? ?? false;

    // Determinar paso actual basado en el progreso
    int currentStep = 1;
    if (photoComplete) currentStep = 2;
    if (personalInfoComplete) currentStep = 3;

    return CompletionStatusModel(
      isComplete: json['complete'] as bool? ?? false,
      currentStep: currentStep,
      photoComplete: photoComplete,
      personalInfoComplete: personalInfoComplete,
      clubSelectionComplete: clubSelectionComplete,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'complete': isComplete,
      'current_step': currentStep,
      'photo_complete': photoComplete,
      'personal_info_complete': personalInfoComplete,
      'club_selection_complete': clubSelectionComplete,
    };
  }
}
