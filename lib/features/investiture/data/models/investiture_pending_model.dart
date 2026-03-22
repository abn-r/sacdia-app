import 'package:equatable/equatable.dart';
import '../../domain/entities/investiture_pending.dart';
import '../../domain/entities/investiture_status.dart';

/// Modelo de datos para un enrollment pendiente de validación.
///
/// Mapea la respuesta de GET /api/v1/investiture/pending.
class InvestiturePendingModel extends Equatable {
  final int enrollmentId;
  final InvestitureStatus status;
  final DateTime? submittedAt;
  final String? comments;

  final String userId;
  final String userName;
  final String? userLastName;
  final String? userEmail;
  final String? userPhotoUrl;

  final int? classId;
  final String? className;

  final int? clubId;
  final String? clubName;

  const InvestiturePendingModel({
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

  factory InvestiturePendingModel.fromJson(Map<String, dynamic> json) {
    // El backend anida los datos del usuario dentro de un objeto 'user'
    // y los datos de la clase dentro de 'progressive_class' o 'class'.
    final user = json['user'] as Map<String, dynamic>?;
    final classData = (json['progressive_class'] ?? json['class']) as Map<String, dynamic>?;
    final club = json['club'] as Map<String, dynamic>?;

    return InvestiturePendingModel(
      enrollmentId: (json['enrollment_id'] ?? json['id']) as int,
      status: InvestitureStatus.fromString(
        (json['investiture_status'] ?? json['status'] ?? 'IN_PROGRESS') as String,
      ),
      submittedAt: json['submitted_at'] != null
          ? DateTime.tryParse(json['submitted_at'] as String)
          : null,
      comments: json['comments'] as String?,
      userId: (user?['user_id'] ?? user?['id'] ?? json['user_id'] ?? '') as String,
      userName: (user?['name'] ?? json['user_name'] ?? '') as String,
      userLastName: (user?['last_name'] ?? json['user_last_name']) as String?,
      userEmail: (user?['email'] ?? json['user_email']) as String?,
      userPhotoUrl: (user?['photo_url'] ?? json['user_photo_url']) as String?,
      classId: (classData?['class_id'] ?? classData?['id'] ?? json['class_id']) as int?,
      className: (classData?['name'] ?? json['class_name']) as String?,
      clubId: (club?['club_id'] ?? club?['id'] ?? json['club_id']) as int?,
      clubName: (club?['name'] ?? json['club_name']) as String?,
    );
  }

  InvestiturePending toEntity() {
    return InvestiturePending(
      enrollmentId: enrollmentId,
      status: status,
      submittedAt: submittedAt,
      comments: comments,
      userId: userId,
      userName: userName,
      userLastName: userLastName,
      userEmail: userEmail,
      userPhotoUrl: userPhotoUrl,
      classId: classId,
      className: className,
      clubId: clubId,
      clubName: clubName,
    );
  }

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
