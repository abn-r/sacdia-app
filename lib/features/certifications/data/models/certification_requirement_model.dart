import 'package:equatable/equatable.dart';

import '../../domain/entities/certification_requirement.dart';
import '../../domain/entities/certification_requirement_component.dart';

/// Modelo de la respuesta guardada de un componente.
class CertificationComponentResponseModel extends Equatable {
  final String? textValue;
  final bool? attestationConfirmed;
  final int? linkedUserHonorId;
  final int? linkedActivityId;

  const CertificationComponentResponseModel({
    this.textValue,
    this.attestationConfirmed,
    this.linkedUserHonorId,
    this.linkedActivityId,
  });

  factory CertificationComponentResponseModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return CertificationComponentResponseModel(
      textValue: json['text_value'] as String?,
      attestationConfirmed: json['attestation_confirmed'] as bool?,
      linkedUserHonorId: json['linked_user_honor_id'] as int?,
      linkedActivityId: json['linked_activity_id'] as int?,
    );
  }

  CertificationComponentResponse toEntity() => CertificationComponentResponse(
        textValue: textValue,
        attestationConfirmed: attestationConfirmed,
        linkedUserHonorId: linkedUserHonorId,
        linkedActivityId: linkedActivityId,
      );

  @override
  List<Object?> get props => [
        textValue,
        attestationConfirmed,
        linkedUserHonorId,
        linkedActivityId,
      ];
}

/// Modelo de un componente de requisito.
class CertificationRequirementComponentModel extends Equatable {
  final int componentId;
  final String componentType;
  final String label;
  final bool required;
  final CertificationComponentResponseModel? response;

  const CertificationRequirementComponentModel({
    required this.componentId,
    required this.componentType,
    required this.label,
    required this.required,
    this.response,
  });

  factory CertificationRequirementComponentModel.fromJson(
    Map<String, dynamic> json,
  ) {
    final responseJson = json['response'] as Map<String, dynamic>?;
    return CertificationRequirementComponentModel(
      componentId: json['component_id'] as int,
      componentType: json['component_type'] as String,
      label: json['label'] as String? ?? '',
      required: json['required'] as bool? ?? false,
      response: responseJson != null
          ? CertificationComponentResponseModel.fromJson(responseJson)
          : null,
    );
  }

  CertificationRequirementComponent toEntity() =>
      CertificationRequirementComponent(
        componentId: componentId,
        type: certificationComponentTypeFromWire(componentType),
        label: label,
        required: required,
        response: response?.toEntity(),
      );

  @override
  List<Object?> get props =>
      [componentId, componentType, label, required, response];
}

/// Modelo de `RequirementView` (backend) — requisito con sus componentes.
class CertificationRequirementModel extends Equatable {
  final int sectionId;
  final int moduleId;
  final String name;
  final bool required;
  final String status;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final String? lastReviewComment;
  final List<CertificationRequirementComponentModel> components;

  const CertificationRequirementModel({
    required this.sectionId,
    required this.moduleId,
    required this.name,
    required this.required,
    required this.status,
    this.submittedAt,
    this.reviewedAt,
    this.lastReviewComment,
    this.components = const [],
  });

  factory CertificationRequirementModel.fromJson(Map<String, dynamic> json) {
    return CertificationRequirementModel(
      sectionId: json['section_id'] as int,
      moduleId: json['module_id'] as int,
      name: json['name'] as String? ?? '',
      required: json['required'] as bool? ?? false,
      status: json['status'] as String? ?? 'DRAFT',
      submittedAt: json['submitted_at'] != null
          ? DateTime.tryParse(json['submitted_at'] as String)
          : null,
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.tryParse(json['reviewed_at'] as String)
          : null,
      lastReviewComment: json['last_review_comment'] as String?,
      components: (json['components'] as List<dynamic>?)
              ?.map((c) => CertificationRequirementComponentModel.fromJson(
                    c as Map<String, dynamic>,
                  ))
              .toList() ??
          const [],
    );
  }

  CertificationRequirement toEntity() => CertificationRequirement(
        sectionId: sectionId,
        moduleId: moduleId,
        name: name,
        required: required,
        status: certificationRequirementStatusFromWire(status),
        submittedAt: submittedAt,
        reviewedAt: reviewedAt,
        lastReviewComment: lastReviewComment,
        components: components.map((c) => c.toEntity()).toList(),
      );

  @override
  List<Object?> get props => [
        sectionId,
        moduleId,
        name,
        required,
        status,
        submittedAt,
        reviewedAt,
        lastReviewComment,
        components,
      ];
}

/// Modelo de `ProgressSummary` (backend) — NOTA: a diferencia del resto del
/// contrato (snake_case), este sub-objeto viaja en camelCase porque el
/// backend lo serializa directamente desde `computeProgressSummary` sin
/// pasar por un DTO de transformación. Ver
/// `certification-state-machine.ts`.
class CertificationProgressSummaryModel extends Equatable {
  final int requiredTotal;
  final int requiredApproved;
  final int optionalTotal;
  final int optionalApproved;
  final int percentComplete;
  final bool allRequiredApproved;

  const CertificationProgressSummaryModel({
    required this.requiredTotal,
    required this.requiredApproved,
    required this.optionalTotal,
    required this.optionalApproved,
    required this.percentComplete,
    required this.allRequiredApproved,
  });

  factory CertificationProgressSummaryModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return CertificationProgressSummaryModel(
      requiredTotal: (json['requiredTotal'] as num?)?.toInt() ?? 0,
      requiredApproved: (json['requiredApproved'] as num?)?.toInt() ?? 0,
      optionalTotal: (json['optionalTotal'] as num?)?.toInt() ?? 0,
      optionalApproved: (json['optionalApproved'] as num?)?.toInt() ?? 0,
      percentComplete: (json['percentComplete'] as num?)?.toInt() ?? 0,
      allRequiredApproved: json['allRequiredApproved'] as bool? ?? false,
    );
  }

  CertificationProgressSummary toEntity() => CertificationProgressSummary(
        requiredTotal: requiredTotal,
        requiredApproved: requiredApproved,
        optionalTotal: optionalTotal,
        optionalApproved: optionalApproved,
        percentComplete: percentComplete,
        allRequiredApproved: allRequiredApproved,
      );

  @override
  List<Object?> get props => [
        requiredTotal,
        requiredApproved,
        optionalTotal,
        optionalApproved,
        percentComplete,
        allRequiredApproved,
      ];
}

/// Modelo del resultado de `submitRequirement`.
class CertificationRequirementSubmitResultModel extends Equatable {
  final CertificationRequirementModel requirement;
  final CertificationProgressSummaryModel progressSummary;

  const CertificationRequirementSubmitResultModel({
    required this.requirement,
    required this.progressSummary,
  });

  factory CertificationRequirementSubmitResultModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return CertificationRequirementSubmitResultModel(
      requirement: CertificationRequirementModel.fromJson(
        json['requirement'] as Map<String, dynamic>,
      ),
      progressSummary: CertificationProgressSummaryModel.fromJson(
        json['progress_summary'] as Map<String, dynamic>,
      ),
    );
  }

  CertificationRequirementSubmitResult toEntity() =>
      CertificationRequirementSubmitResult(
        requirement: requirement.toEntity(),
        progressSummary: progressSummary.toEntity(),
      );

  @override
  List<Object?> get props => [requirement, progressSummary];
}
