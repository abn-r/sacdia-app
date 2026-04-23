import '../../domain/entities/qr_member_token.dart';

class QrMemberTokenModel extends QrMemberToken {
  const QrMemberTokenModel({
    required super.token,
    required super.expiresAt,
    required super.expiresIn,
  });

  factory QrMemberTokenModel.fromJson(Map<String, dynamic> json) {
    return QrMemberTokenModel(
      token: json['token'] as String,
      expiresAt: DateTime.parse(json['expires_at'] as String).toUtc(),
      expiresIn: (json['expires_in'] as num).toInt(),
    );
  }
}
