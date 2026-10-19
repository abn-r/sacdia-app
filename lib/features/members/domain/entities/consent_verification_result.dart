import 'package:equatable/equatable.dart';

/// Respuesta de `POST .../verify-consent` (200).
///
/// El consentimiento YA quedó verificado cuando esto se devuelve. Si se pidió
/// aprobar y la aprobación falló después del commit, [approveError] trae el
/// código y [approved] es `false`: reintentar la misma llamada solo reintenta la
/// aprobación.
class ConsentVerificationResult extends Equatable {
  final String guardianshipId;
  final DateTime? verifiedAt;
  final String? verifiedByUserId;
  final String? verificationMethod;

  /// La solicitud quedó aprobada (el backend devolvió la asignación).
  final bool approved;

  /// Código de error de la aprobación que falló tras verificar (`MR_*`, ...).
  final String? approveError;

  const ConsentVerificationResult({
    required this.guardianshipId,
    required this.approved,
    this.verifiedAt,
    this.verifiedByUserId,
    this.verificationMethod,
    this.approveError,
  });

  /// Verificado pero no aprobado por un fallo reintentable.
  bool get approvalFailed => approveError != null;

  @override
  List<Object?> get props => [
        guardianshipId,
        verifiedAt,
        verifiedByUserId,
        verificationMethod,
        approved,
        approveError,
      ];
}
