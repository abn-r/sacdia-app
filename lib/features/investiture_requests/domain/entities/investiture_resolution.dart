import 'package:equatable/equatable.dart';

import 'investiture_request.dart';
import 'person_status.dart';

/// Decisión de investir a una persona.
class InvestDecision extends Equatable {
  const InvestDecision({required this.personId, this.comment});

  final String personId;
  final String? comment;

  @override
  List<Object?> get props => [personId, comment];
}

/// Decisión de rechazar a una persona (el motivo es obligatorio).
class RejectDecision extends Equatable {
  const RejectDecision({required this.personId, required this.reason});

  final String personId;
  final String reason;

  @override
  List<Object?> get props => [personId, reason];
}

/// Persona cuya decisión no se aplicó, con el código de error del backend.
class BlockedDecision extends Equatable {
  const BlockedDecision({required this.personId, required this.code});

  final String personId;
  final String code;

  @override
  List<Object?> get props => [personId, code];
}

/// Persona que ya estaba resuelta cuando llegó la decisión.
class AlreadyResolvedDecision extends Equatable {
  const AlreadyResolvedDecision({
    required this.personId,
    required this.status,
  });

  final String personId;
  final PersonStatus status;

  @override
  List<Object?> get props => [personId, status];
}

/// Resultado de `POST /investiture-requests/{id}/resolutions`.
class InvestitureResolution extends Equatable {
  const InvestitureResolution({
    required this.requestId,
    required this.invested,
    required this.rejectedByPerson,
    required this.rejectedBySystem,
    required this.retired,
    required this.blocked,
    required this.alreadyResolved,
  });

  final String requestId;
  final List<RequestPerson> invested;
  final List<RequestPerson> rejectedByPerson;
  final List<RequestPerson> rejectedBySystem;
  final List<RequestPerson> retired;
  final List<BlockedDecision> blocked;
  final List<AlreadyResolvedDecision> alreadyResolved;

  @override
  List<Object?> get props => [
        requestId,
        invested,
        rejectedByPerson,
        rejectedBySystem,
        retired,
        blocked,
        alreadyResolved,
      ];
}
