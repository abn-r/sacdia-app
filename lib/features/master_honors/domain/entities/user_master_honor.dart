import 'package:equatable/equatable.dart';

/// Maestría obtenida o histórica de un usuario.
class UserMasterHonor extends Equatable {
  final int userMasterHonorId;
  final int masterHonorId;
  final String name;
  final String? masterImage;
  final String status;
  final bool isCurrent;
  final String displayStatusLabel;
  final DateTime? awardedAt;
  final DateTime? revokedAt;
  final DateTime? recoveredAt;
  final String? statusReason;

  const UserMasterHonor({
    required this.userMasterHonorId,
    required this.masterHonorId,
    required this.name,
    this.masterImage,
    required this.status,
    required this.isCurrent,
    required this.displayStatusLabel,
    this.awardedAt,
    this.revokedAt,
    this.recoveredAt,
    this.statusReason,
  });

  bool get isNoCurrent => !isCurrent;

  @override
  List<Object?> get props => [
        userMasterHonorId,
        masterHonorId,
        name,
        masterImage,
        status,
        isCurrent,
        displayStatusLabel,
        awardedAt,
        revokedAt,
        recoveredAt,
        statusReason,
      ];
}
