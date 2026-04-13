import 'package:equatable/equatable.dart';
import 'investiture_status.dart';

/// Entidad que representa un miembro con su estado de investidura actual.
///
/// Usada en InvestitureSubmitView para listar los miembros de la sección
/// y permitir al director/consejero enviar para validación.
class InvestitureMember extends Equatable {
  final String userId;
  final String userName;
  final String? userLastName;
  final String? userPhotoUrl;

  final int enrollmentId;
  final InvestitureStatus investitureStatus;
  final String? className;
  final int? classId;

  const InvestitureMember({
    required this.userId,
    required this.userName,
    this.userLastName,
    this.userPhotoUrl,
    required this.enrollmentId,
    required this.investitureStatus,
    this.className,
    this.classId,
  });

  /// Nombre completo del miembro.
  String get fullName =>
      userLastName != null ? '$userName $userLastName' : userName;

  @override
  List<Object?> get props => [
        userId,
        userName,
        userLastName,
        userPhotoUrl,
        enrollmentId,
        investitureStatus,
        className,
        classId,
      ];
}
