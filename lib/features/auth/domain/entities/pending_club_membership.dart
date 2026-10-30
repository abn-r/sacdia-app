import 'package:equatable/equatable.dart';

/// Solicitud de ingreso a un club que el principal envió y sigue sin
/// resolverse (`/auth/me.pending_club_membership`).
///
/// El servidor solo la trae para un teléfono vinculado o un adolescente
/// supervisado SIN club activo. Se deriva en cada carga y nunca se cachea.
/// Ausente (servidor anterior) o `null` significa que no hay solicitud pendiente
/// conocida.
class PendingClubMembership extends Equatable {
  final String clubName;
  final String? clubTypeName;
  final int? clubSectionId;
  final DateTime? requestedAt;

  const PendingClubMembership({
    required this.clubName,
    this.clubTypeName,
    this.clubSectionId,
    this.requestedAt,
  });

  @override
  List<Object?> get props => [
        clubName,
        clubTypeName,
        clubSectionId,
        requestedAt,
      ];
}
