import 'package:equatable/equatable.dart';

import '../../../../core/utils/json_helpers.dart';
import '../../domain/entities/user_master_honor.dart';

class UserMasterHonorModel extends Equatable {
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

  const UserMasterHonorModel({
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

  factory UserMasterHonorModel.fromJson(Map<String, dynamic> json) {
    return UserMasterHonorModel(
      userMasterHonorId: safeInt(json['user_master_honor_id']),
      masterHonorId: safeInt(json['master_honor_id']),
      name: safeString(json['name']),
      masterImage: safeStringOrNull(json['master_image']),
      status: safeString(json['status']),
      isCurrent: safeBool(json['is_current']),
      displayStatusLabel: safeString(json['display_status_label']),
      awardedAt: _parseDate(json['awarded_at']),
      revokedAt: _parseDate(json['revoked_at']),
      recoveredAt: _parseDate(json['recovered_at']),
      statusReason: safeStringOrNull(json['status_reason']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_master_honor_id': userMasterHonorId,
      'master_honor_id': masterHonorId,
      'name': name,
      'master_image': masterImage,
      'status': status,
      'is_current': isCurrent,
      'display_status_label': displayStatusLabel,
      'awarded_at': awardedAt?.toIso8601String(),
      'revoked_at': revokedAt?.toIso8601String(),
      'recovered_at': recoveredAt?.toIso8601String(),
      'status_reason': statusReason,
    };
  }

  UserMasterHonor toEntity() {
    return UserMasterHonor(
      userMasterHonorId: userMasterHonorId,
      masterHonorId: masterHonorId,
      name: name,
      masterImage: masterImage,
      status: status,
      isCurrent: isCurrent,
      displayStatusLabel: displayStatusLabel,
      awardedAt: awardedAt,
      revokedAt: revokedAt,
      recoveredAt: recoveredAt,
      statusReason: statusReason,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    final raw = safeStringOrNull(value);
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

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
