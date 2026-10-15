import 'package:equatable/equatable.dart';

import 'person_status.dart';

/// Entrada del historial de investidura (propio o de la sección).
///
/// Para la propia persona, un rechazo llega como [PersonStatus.rejected] y sin
/// motivo. La directiva puede recibir `rejectionReason`/`systemReason`.
class OwnInvestitureEntry extends Equatable {
  const OwnInvestitureEntry({
    required this.personId,
    required this.userId,
    required this.classId,
    this.className,
    required this.clubSectionId,
    required this.ecclesiasticalYearId,
    required this.investitureDate,
    required this.status,
    this.rejectionReason,
    this.systemReason,
    this.personText,
    this.authorizationComment,
  });

  final String personId;
  final String userId;
  final int classId;
  final String? className;
  final int clubSectionId;
  final int ecclesiasticalYearId;
  final DateTime investitureDate;
  final PersonStatus status;
  final String? rejectionReason;
  final String? systemReason;

  /// Texto cerrado que el backend define para la persona (p. ej. retiro).
  final String? personText;
  final String? authorizationComment;

  @override
  List<Object?> get props => [
        personId,
        userId,
        classId,
        className,
        clubSectionId,
        ecclesiasticalYearId,
        investitureDate,
        status,
        rejectionReason,
        systemReason,
        personText,
        authorizationComment,
      ];
}
