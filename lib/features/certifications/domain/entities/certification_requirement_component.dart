import 'package:equatable/equatable.dart';

/// Tipos de componente de un requisito de certificación.
///
/// Reflejan 1:1 `CERTIFICATION_COMPONENT_TYPES` del backend
/// (`certification-definition.types.ts`). La UI debe interpretar
/// exclusivamente [CertificationRequirementComponent.type] — nunca el nombre
/// o ID de la certificación — para decidir qué campo renderizar.
enum CertificationComponentType {
  textResponse,
  fileEvidence,
  linkedHonor,
  linkedActivity,
  attestation,
  autoValidation,

  /// Tipo desconocido — permite que la app siga funcionando (modo solo
  /// lectura para ese componente) si el backend agrega un tipo nuevo.
  unknown,
}

/// Convierte el valor `component_type` recibido del backend (p.ej.
/// `'TEXT_RESPONSE'`) al enum de dominio.
CertificationComponentType certificationComponentTypeFromWire(String? value) {
  switch (value) {
    case 'TEXT_RESPONSE':
      return CertificationComponentType.textResponse;
    case 'FILE_EVIDENCE':
      return CertificationComponentType.fileEvidence;
    case 'LINKED_HONOR':
      return CertificationComponentType.linkedHonor;
    case 'LINKED_ACTIVITY':
      return CertificationComponentType.linkedActivity;
    case 'ATTESTATION':
      return CertificationComponentType.attestation;
    case 'AUTO_VALIDATION':
      return CertificationComponentType.autoValidation;
    default:
      return CertificationComponentType.unknown;
  }
}

/// Extensión para serializar el enum de vuelta al valor wire del backend.
extension CertificationComponentTypeWire on CertificationComponentType {
  String get wireValue {
    switch (this) {
      case CertificationComponentType.textResponse:
        return 'TEXT_RESPONSE';
      case CertificationComponentType.fileEvidence:
        return 'FILE_EVIDENCE';
      case CertificationComponentType.linkedHonor:
        return 'LINKED_HONOR';
      case CertificationComponentType.linkedActivity:
        return 'LINKED_ACTIVITY';
      case CertificationComponentType.attestation:
        return 'ATTESTATION';
      case CertificationComponentType.autoValidation:
        return 'AUTO_VALIDATION';
      case CertificationComponentType.unknown:
        return 'UNKNOWN';
    }
  }
}

/// Respuesta guardada de un componente (borrador o enviada).
///
/// Todos los campos son opcionales porque cada [CertificationComponentType]
/// solo usa un subconjunto (ver `isComponentResponseComplete` en el backend).
class CertificationComponentResponse extends Equatable {
  final String? textValue;
  final bool? attestationConfirmed;
  final int? linkedUserHonorId;
  final int? linkedActivityId;

  const CertificationComponentResponse({
    this.textValue,
    this.attestationConfirmed,
    this.linkedUserHonorId,
    this.linkedActivityId,
  });

  @override
  List<Object?> get props => [
        textValue,
        attestationConfirmed,
        linkedUserHonorId,
        linkedActivityId,
      ];
}

/// Componente de un requisito (sección) de certificación.
class CertificationRequirementComponent extends Equatable {
  final int componentId;
  final CertificationComponentType type;
  final String label;
  final bool required;
  final CertificationComponentResponse? response;

  const CertificationRequirementComponent({
    required this.componentId,
    required this.type,
    required this.label,
    required this.required,
    this.response,
  });

  /// Replica `isComponentResponseComplete` del backend para dar feedback
  /// inmediato en la UI antes de intentar el envío (el backend sigue siendo
  /// la fuente de verdad final).
  bool get isComplete {
    switch (type) {
      case CertificationComponentType.autoValidation:
        return true;
      case CertificationComponentType.textResponse:
        return (response?.textValue?.trim().isNotEmpty ?? false);
      case CertificationComponentType.attestation:
        return response?.attestationConfirmed == true;
      case CertificationComponentType.linkedHonor:
        return response?.linkedUserHonorId != null;
      case CertificationComponentType.linkedActivity:
        return response?.linkedActivityId != null;
      case CertificationComponentType.fileEvidence:
        return response != null;
      case CertificationComponentType.unknown:
        return false;
    }
  }

  @override
  List<Object?> get props => [componentId, type, label, required, response];
}

/// Entrada de borrador para `PUT .../requirements/:sectionId/draft`.
///
/// Espejo de `RequirementComponentResponseDto` del backend. Vive en el
/// dominio (no en `data/models`) porque la UI la construye directamente al
/// capturar la interacción del usuario, sin pasar por un modelo de wire.
class CertificationComponentDraftInput extends Equatable {
  final int componentId;
  final String? textValue;
  final bool? attestationConfirmed;
  final int? linkedUserHonorId;
  final int? linkedActivityId;

  const CertificationComponentDraftInput({
    required this.componentId,
    this.textValue,
    this.attestationConfirmed,
    this.linkedUserHonorId,
    this.linkedActivityId,
  });

  Map<String, dynamic> toJson() => {
        'component_id': componentId,
        if (textValue != null) 'text_value': textValue,
        if (attestationConfirmed != null)
          'attestation_confirmed': attestationConfirmed,
        if (linkedUserHonorId != null)
          'linked_user_honor_id': linkedUserHonorId,
        if (linkedActivityId != null) 'linked_activity_id': linkedActivityId,
      };

  @override
  List<Object?> get props => [
        componentId,
        textValue,
        attestationConfirmed,
        linkedUserHonorId,
        linkedActivityId,
      ];
}
