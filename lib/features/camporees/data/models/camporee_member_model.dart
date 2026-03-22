import 'package:equatable/equatable.dart';
import '../../domain/entities/camporee_member.dart';

/// Modelo de miembro de camporee para la capa de datos
class CamporeeMemberModel extends Equatable {
  final int camporeeMemberId;
  final String userId;
  final String? userName;
  final String? userEmail;
  final String? userImageUrl;
  final String? clubName;
  final bool insuranceVerified;
  final bool active;
  final String? camporeeType;
  final int? insuranceId;

  const CamporeeMemberModel({
    required this.camporeeMemberId,
    required this.userId,
    this.userName,
    this.userEmail,
    this.userImageUrl,
    this.clubName,
    required this.insuranceVerified,
    required this.active,
    this.camporeeType,
    this.insuranceId,
  });

  /// Crea una instancia desde JSON (snake_case → camelCase)
  factory CamporeeMemberModel.fromJson(Map<String, dynamic> json) {
    final users = json['users'] as Map<String, dynamic>?;
    final insurance = json['insurance'] as Map<String, dynamic>?;

    // Build full name from user parts
    String? userName;
    if (users != null) {
      final name = users['name'] as String?;
      final paternalLastName = users['paternal_last_name'] as String?;
      final maternalLastName = users['maternal_last_name'] as String?;
      final parts = [name, paternalLastName, maternalLastName]
          .where((p) => p != null && p.isNotEmpty)
          .toList();
      userName = parts.isNotEmpty ? parts.join(' ') : null;
    }

    return CamporeeMemberModel(
      camporeeMemberId: (json['camporee_member_id'] ?? json['id']) as int,
      userId: (users != null ? users['user_id'] : json['user_id']) as String,
      userName: userName,
      userEmail: users != null ? users['email'] as String? : null,
      userImageUrl: users != null ? users['user_image'] as String? : null,
      clubName: json['club_name'] as String?,
      insuranceVerified: json['insurance_verified'] as bool? ?? false,
      active: json['active'] as bool? ?? true,
      camporeeType: json['camporee_type'] as String?,
      insuranceId: insurance != null
          ? insurance['insurance_id'] as int?
          : json['insurance_id'] as int?,
    );
  }

  /// Convierte el modelo a entidad de dominio
  CamporeeMember toEntity() {
    return CamporeeMember(
      camporeeMemberId: camporeeMemberId,
      userId: userId,
      userName: userName,
      userEmail: userEmail,
      userImageUrl: userImageUrl,
      clubName: clubName,
      insuranceVerified: insuranceVerified,
      active: active,
      camporeeType: camporeeType,
      insuranceId: insuranceId,
    );
  }

  @override
  List<Object?> get props => [
        camporeeMemberId,
        userId,
        userName,
        userEmail,
        userImageUrl,
        clubName,
        insuranceVerified,
        active,
        camporeeType,
        insuranceId,
      ];
}
