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
    final data = json['data'] as Map<String, dynamic>? ?? json;
    final steps = data['steps'] as Map<String, dynamic>? ?? {};

    final isComplete = data['complete'] as bool? ?? false;
    final nextStep = data['nextStep'] as String?;

    final photoComplete = steps['profilePicture'] as bool? ?? false;
    final personalInfoComplete = steps['personalInfo'] as bool? ?? false;
    final clubSelectionComplete = steps['clubSelection'] as bool? ?? false;

    int currentStep;
    if (isComplete && nextStep == null) {
      currentStep = 3;
    } else {
      switch (nextStep) {
        case 'profilePicture':
          currentStep = 1;
          break;
        case 'personalInfo':
          currentStep = 2;
          break;
        case 'clubSelection':
          currentStep = 3;
          break;
        default:
          currentStep = 1;
      }
    }

    return CompletionStatusModel(
      isComplete: isComplete,
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
