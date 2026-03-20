import 'package:equatable/equatable.dart';

/// Entidad de miembro inscripto en un camporee
class CamporeeMember extends Equatable {
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

  const CamporeeMember({
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
