import 'package:equatable/equatable.dart';
import 'investiture_status.dart';

/// Entidad que representa un enrollment pendiente de validación de investidura.
///
/// Devuelta por GET /api/v1/investiture/pending (solo coordinadores/admins).
class InvestiturePending extends Equatable {
  final int enrollmentId;
  final InvestitureStatus status;
  final DateTime? submittedAt;
  final String? comments;

  // Datos del usuario inscrito
  final String userId;
  final String userName;
  final String? userLastName;
  final String? userEmail;
  final String? userPhotoUrl;

  // Datos de la clase/categoría
  final int? classId;
  final String? className;

  // Datos del club
  final int? clubId;
  final String? clubName;

  const InvestiturePending({
    required this.enrollmentId,
    required this.status,
    this.submittedAt,
    this.comments,
    required this.userId,
    required this.userName,
    this.userLastName,
    this.userEmail,
    this.userPhotoUrl,
    this.classId,
    this.className,
    this.clubId,
    this.clubName,
  });

  /// Nombre completo del usuario.
  String get fullName =>
      userLastName != null ? '$userName $userLastName' : userName;

  @override
  List<Object?> get props => [
        enrollmentId,
        status,
        submittedAt,
        comments,
        userId,
        userName,
        userLastName,
        userEmail,
        userPhotoUrl,
        classId,
        className,
        clubId,
        clubName,
      ];
}
