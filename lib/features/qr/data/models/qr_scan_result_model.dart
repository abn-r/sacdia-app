import '../../domain/entities/qr_scan_result.dart';

class ScannedMemberModel extends ScannedMember {
  const ScannedMemberModel({
    required super.userId,
    required super.fullName,
    super.avatar,
    super.clubName,
    super.sectionName,
  });

  factory ScannedMemberModel.fromJson(Map<String, dynamic> json) {
    return ScannedMemberModel(
      userId: json['user_id'] as String,
      fullName: (json['full_name'] as String?) ?? '',
      avatar: json['avatar'] as String?,
      clubName: json['club_name'] as String?,
      sectionName: json['section_name'] as String?,
    );
  }
}

class ScannedAttendanceModel extends ScannedAttendance {
  const ScannedAttendanceModel({
    required super.registered,
    required super.alreadyPresent,
    required super.activityId,
  });

  factory ScannedAttendanceModel.fromJson(Map<String, dynamic> json) {
    return ScannedAttendanceModel(
      registered: json['registered'] as bool,
      alreadyPresent: json['already_present'] as bool,
      activityId: (json['activity_id'] as num).toInt(),
    );
  }
}

class QrScanResultModel extends QrScanResult {
  const QrScanResultModel({
    required super.member,
    required super.scannedAt,
    super.attendance,
  });

  factory QrScanResultModel.fromJson(Map<String, dynamic> json) {
    final att = json['attendance'];
    return QrScanResultModel(
      member: ScannedMemberModel.fromJson(
        json['member'] as Map<String, dynamic>,
      ),
      attendance: att == null
          ? null
          : ScannedAttendanceModel.fromJson(att as Map<String, dynamic>),
      scannedAt: DateTime.parse(json['scanned_at'] as String).toUtc(),
    );
  }
}
