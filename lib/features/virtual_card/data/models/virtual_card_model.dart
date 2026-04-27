import '../../domain/entities/virtual_card.dart';

class VirtualCardModel extends VirtualCard {
  const VirtualCardModel({
    required super.userId,
    required super.fullName,
    required super.qrToken,
    required super.qrExpiresAt,
    required super.isActive,
    super.photoUrl,
    super.roleLabel,
    super.roleCode,
    super.clubName,
    super.clubLogoUrl,
    super.sectionName,
    super.memberSince,
    super.achievementTier,
    super.cardIdShort,
    super.isOffline,
  });

  factory VirtualCardModel.fromJson(Map<String, dynamic> json) {
    final club = json['club'] is Map<String, dynamic>
        ? json['club'] as Map<String, dynamic>
        : null;
    final rawMemberSince = json['member_since'] as String? ??
        json['created_at'] as String? ??
        json['createdAt'] as String?;
    final rawExpiresAt = json['qr_expires_at'] as String? ??
        json['expires_at'] as String? ??
        json['expiresAt'] as String?;

    return VirtualCardModel(
      userId: (json['user_id'] as String? ?? json['id'] as String? ?? '').trim(),
      fullName: (json['name_full'] as String? ??
              json['full_name'] as String? ??
              json['name'] as String? ??
              '')
          .trim(),
      photoUrl: json['photo_url'] as String? ??
          json['avatar'] as String? ??
          json['user_image'] as String?,
      roleLabel: json['role_label'] as String? ??
          json['role'] as String? ??
          json['role_name'] as String?,
      roleCode: json['role_code'] as String? ??
          json['role_name'] as String? ??
          json['role'] as String?,
      clubName: json['club_name'] as String? ??
          club?['club_name'] as String? ??
          club?['name'] as String?,
      clubLogoUrl: json['club_logo_url'] as String? ??
          json['club_logo'] as String? ??
          club?['logo_url'] as String?,
      sectionName: json['section_name'] as String? ??
          json['section'] as String? ??
          json['current_class'] as String?,
      memberSince: rawMemberSince != null ? DateTime.tryParse(rawMemberSince) : null,
      achievementTier: VirtualCardTier.fromString(
        (json['achievement_tier'] as String? ?? json['tier'] as String?),
      ),
      cardIdShort: json['card_id_short'] as String? ??
          json['card_id'] as String? ??
          json['short_id'] as String?,
      qrToken: json['qr_token'] as String? ?? json['token'] as String?,
      qrExpiresAt:
          rawExpiresAt != null ? DateTime.tryParse(rawExpiresAt)?.toUtc() : null,
      isActive: json['is_active'] as bool? ?? true,
      isOffline: json['is_offline'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'name_full': fullName,
      'photo_url': photoUrl,
      'role_label': roleLabel,
      'role_code': roleCode,
      'club_name': clubName,
      'club_logo_url': clubLogoUrl,
      'section_name': sectionName,
      'member_since': memberSince?.toIso8601String(),
      'achievement_tier': achievementTier?.name,
      'card_id_short': cardIdShort,
      'qr_token': qrToken,
      'qr_expires_at': qrExpiresAt?.toIso8601String(),
      'is_active': isActive,
      'is_offline': isOffline,
    };
  }
}
