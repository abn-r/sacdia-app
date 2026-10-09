import 'package:equatable/equatable.dart';

/// Ventana del Campo para presentar o agregar personas.
class WindowState extends Equatable {
  const WindowState({
    this.startDate,
    this.endDate,
    required this.openToday,
    this.timeZoneInvalid = false,
  });

  /// Fechas civiles (sin zona). Pueden ser nulas si el Campo no configuró la ventana.
  final DateTime? startDate;
  final DateTime? endDate;
  final bool openToday;

  /// La zona horaria guardada del Campo no es válida: `openToday` es falso.
  final bool timeZoneInvalid;

  @override
  List<Object?> get props => [startDate, endDate, openToday, timeZoneInvalid];
}

/// Persona de la sección que la directiva puede (o no) presentar.
class PresentationCandidate extends Equatable {
  const PresentationCandidate({
    required this.enrollmentId,
    required this.userId,
    this.userName,
    required this.classId,
    this.className,
    required this.overallProgress,
    required this.eligible,
    this.blockedCode,
    this.pendingPersonId,
  });

  final int enrollmentId;
  final String userId;
  final String? userName;
  final int classId;
  final String? className;
  final num overallProgress;
  final bool eligible;

  /// Código de error del backend que explica por qué no puede presentarse.
  final String? blockedCode;

  /// Presente cuando la persona ya está PENDING en la solicitud abierta.
  final String? pendingPersonId;

  @override
  List<Object?> get props => [
        enrollmentId,
        userId,
        userName,
        classId,
        className,
        overallProgress,
        eligible,
        blockedCode,
        pendingPersonId,
      ];
}

/// Contexto para presentar personas a investidura en una sección y año.
class PresentationContext extends Equatable {
  const PresentationContext({
    required this.clubSectionId,
    required this.ecclesiasticalYearId,
    required this.window,
    required this.yearOpen,
    this.openRequestId,
    required this.candidates,
  });

  final int clubSectionId;
  final int ecclesiasticalYearId;
  final WindowState window;
  final bool yearOpen;
  final String? openRequestId;
  final List<PresentationCandidate> candidates;

  @override
  List<Object?> get props => [
        clubSectionId,
        ecclesiasticalYearId,
        window,
        yearOpen,
        openRequestId,
        candidates,
      ];
}
