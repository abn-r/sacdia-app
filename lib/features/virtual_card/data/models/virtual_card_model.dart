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
    final member = json['member'] is Map
        ? Map<String, dynamic>.from(json['member'] as Map)
        : null;
    final visual = json['visual'] is Map
        ? Map<String, dynamic>.from(json['visual'] as Map)
        : null;
    final club = json['club'] is Map<String, dynamic>
        ? json['club'] as Map<String, dynamic>
        : null;
    final rawMemberSince = json['member_since'] as String? ??
        json['created_at'] as String? ??
        json['createdAt'] as String?;
    final rawExpiresAt = json['qr_expires_at'] as String? ??
        json['expires_at'] as String? ??
        json['expiresAt'] as String?;
    final userId = _pickString([
      json['user_id'],
      member?['user_id'],
      json['id'],
    ]);
    final cardIdShort = _pickString([
      json['card_id_short'],
      json['card_id'],
      json['short_id'],
      userId == null ? null : _shortId(userId),
    ]);

    return VirtualCardModel(
      userId: userId ?? '',
      fullName: _pickString([
            json['name_full'],
            json['full_name'],
            member?['full_name'],
            visual?['primary_line'],
            json['name'],
          ]) ??
          '',
      photoUrl: _pickString([
        json['photo_url'],
        json['avatar'],
        member?['avatar'],
        json['user_image'],
      ]),
      roleLabel: _pickString([
        json['role_label'],
        json['role'],
        json['role_name'],
      ]),
      roleCode: _pickString([
        json['role_code'],
        json['role_name'],
        json['role'],
      ]),
      clubName: _pickString([
        json['club_name'],
        member?['club_name'],
        visual?['club_name'],
        club?['club_name'],
        club?['name'],
      ]),
      clubLogoUrl: json['club_logo_url'] as String? ??
          json['club_logo'] as String? ??
          club?['logo_url'] as String?,
      sectionName: _pickString([
        json['section_name'],
        member?['section_name'],
        visual?['section_name'],
        json['section'],
        json['current_class'],
      ]),
      memberSince:
          rawMemberSince != null ? DateTime.tryParse(rawMemberSince) : null,
      achievementTier: VirtualCardTier.fromString(
        (json['achievement_tier'] as String? ?? json['tier'] as String?),
      ),
      cardIdShort: cardIdShort,
      qrToken: json['qr_token'] as String? ?? json['token'] as String?,
      qrExpiresAt: rawExpiresAt != null
          ? DateTime.tryParse(rawExpiresAt)?.toUtc()
          : null,
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

  static String? _pickString(Iterable<Object?> values) {
    for (final value in values) {
      final normalized = value?.toString().trim();
      if (normalized != null && normalized.isNotEmpty) {
        return normalized;
      }
    }
    return null;
  }

  static String _shortId(String value) {
    final normalized = value.trim();
    if (normalized.length <= 8) return normalized;
    return normalized.substring(normalized.length - 8);
  }
}
