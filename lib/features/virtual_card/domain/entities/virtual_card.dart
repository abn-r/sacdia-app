import 'package:equatable/equatable.dart';

enum VirtualCardTier {
  bronze,
  silver,
  gold,
  platinum,
  diamond,
  unknown;

  factory VirtualCardTier.fromString(String? value) {
    switch (value?.trim().toLowerCase()) {
      case 'bronze':
        return VirtualCardTier.bronze;
      case 'silver':
        return VirtualCardTier.silver;
      case 'gold':
        return VirtualCardTier.gold;
      case 'platinum':
        return VirtualCardTier.platinum;
      case 'diamond':
        return VirtualCardTier.diamond;
      default:
        return VirtualCardTier.unknown;
    }
  }

  String get labelKey => switch (this) {
        VirtualCardTier.bronze => 'virtual_card.tiers.bronze',
        VirtualCardTier.silver => 'virtual_card.tiers.silver',
        VirtualCardTier.gold => 'virtual_card.tiers.gold',
        VirtualCardTier.platinum => 'virtual_card.tiers.platinum',
        VirtualCardTier.diamond => 'virtual_card.tiers.diamond',
        VirtualCardTier.unknown => 'virtual_card.tiers.unknown',
      };
}

class VirtualCard extends Equatable {
  const VirtualCard({
    required this.userId,
    required this.fullName,
    required this.qrToken,
    required this.qrExpiresAt,
    required this.isActive,
    this.photoUrl,
    this.roleLabel,
    this.roleCode,
    this.clubName,
    this.clubLogoUrl,
    this.sectionName,
    this.memberSince,
    this.achievementTier,
    this.cardIdShort,
    this.isOffline = false,
  });

  final String userId;
  final String fullName;
  final String? photoUrl;
  final String? roleLabel;
  final String? roleCode;
  final String? clubName;
  final String? clubLogoUrl;
  final String? sectionName;
  final DateTime? memberSince;
  final VirtualCardTier? achievementTier;
  final String? cardIdShort;
  final String? qrToken;
  final DateTime? qrExpiresAt;
  final bool isActive;
  final bool isOffline;

  bool get hasQr => qrToken?.trim().isNotEmpty ?? false;

  bool get isExpired {
    final expiresAt = qrExpiresAt;
    if (expiresAt == null) return false;
    return DateTime.now().toUtc().isAfter(expiresAt);
  }

  bool get isInactive => !isActive;

  bool get canShowQr => hasQr && !isExpired && !isInactive;

  VirtualCard copyWith({
    String? userId,
    String? fullName,
    String? photoUrl,
    String? roleLabel,
    String? roleCode,
    String? clubName,
    String? clubLogoUrl,
    String? sectionName,
    DateTime? memberSince,
    VirtualCardTier? achievementTier,
    String? cardIdShort,
    String? qrToken,
    DateTime? qrExpiresAt,
    bool? isActive,
    bool? isOffline,
  }) {
    return VirtualCard(
      userId: userId ?? this.userId,
      fullName: fullName ?? this.fullName,
      photoUrl: photoUrl ?? this.photoUrl,
      roleLabel: roleLabel ?? this.roleLabel,
      roleCode: roleCode ?? this.roleCode,
      clubName: clubName ?? this.clubName,
      clubLogoUrl: clubLogoUrl ?? this.clubLogoUrl,
      sectionName: sectionName ?? this.sectionName,
      memberSince: memberSince ?? this.memberSince,
      achievementTier: achievementTier ?? this.achievementTier,
      cardIdShort: cardIdShort ?? this.cardIdShort,
      qrToken: qrToken ?? this.qrToken,
      qrExpiresAt: qrExpiresAt ?? this.qrExpiresAt,
      isActive: isActive ?? this.isActive,
      isOffline: isOffline ?? this.isOffline,
    );
  }

  @override
  List<Object?> get props => [
        userId,
        fullName,
        photoUrl,
        roleLabel,
        roleCode,
        clubName,
        clubLogoUrl,
        sectionName,
        memberSince,
        achievementTier,
        cardIdShort,
        qrToken,
        qrExpiresAt,
        isActive,
        isOffline,
      ];
}
