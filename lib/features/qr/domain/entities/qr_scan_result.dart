import 'package:equatable/equatable.dart';

class ScannedMember extends Equatable {
  const ScannedMember({
    required this.userId,
    required this.fullName,
    this.avatar,
    this.clubName,
    this.sectionName,
  });

  final String userId;
  final String fullName;
  final String? avatar;
  final String? clubName;
  final String? sectionName;

  @override
  List<Object?> get props => [userId, fullName, avatar, clubName, sectionName];
}

class ScannedAttendance extends Equatable {
  const ScannedAttendance({
    required this.registered,
    required this.alreadyPresent,
    required this.activityId,
  });

  final bool registered;
  final bool alreadyPresent;
  final int activityId;

  @override
  List<Object?> get props => [registered, alreadyPresent, activityId];
}

class QrScanResult extends Equatable {
  const QrScanResult({
    required this.member,
    required this.scannedAt,
    this.attendance,
  });

  final ScannedMember member;
  final ScannedAttendance? attendance;
  final DateTime scannedAt;

  @override
  List<Object?> get props => [member, attendance, scannedAt];
}
