import 'package:equatable/equatable.dart';
import '../../domain/entities/camporee_member.dart';
import '../../../../core/utils/json_helpers.dart';

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
      camporeeMemberId: safeInt(json['camporee_member_id'] ?? json['id']),
      userId: safeString(users != null ? users['user_id'] : json['user_id']),
      userName: userName,
      userEmail: users != null ? safeStringOrNull(users['email']) : null,
      userImageUrl: users != null ? safeStringOrNull(users['user_image']) : null,
      clubName: safeStringOrNull(json['club_name']),
      insuranceVerified: safeBool(json['insurance_verified']),
      active: safeBool(json['active'], true),
      camporeeType: safeStringOrNull(json['camporee_type']),
      insuranceId: insurance != null
          ? safeIntOrNull(insurance['insurance_id'])
          : safeIntOrNull(json['insurance_id']),
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
