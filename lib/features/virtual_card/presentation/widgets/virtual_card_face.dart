import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../domain/entities/virtual_card.dart';
import 'virtual_card_qr_tile.dart';

class VirtualCardFace extends StatelessWidget {
  const VirtualCardFace({
    super.key,
    required this.card,
    required this.onShowQr,
    required this.onPhotoTap,
    required this.onRefresh,
  });

  final VirtualCard card;
  final VoidCallback onShowQr;
  final VoidCallback onPhotoTap;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF1A2235) : Colors.white;
    final header = isDark ? const Color(0xFF0B1A36) : const Color(0xFF0F2645);
    final textPrimary =
        isDark ? const Color(0xFFF4F7FB) : const Color(0xFF0F1B2D);
    final textSecondary =
        isDark ? const Color(0xFFA0AABF) : const Color(0xFF5A6378);
    final textTertiary =
        isDark ? const Color(0xFF5A6378) : const Color(0xFF9099AB);
    final divider = isDark ? const Color(0xFF2A344C) : const Color(0xFFE5E8EE);

    final tier = card.achievementTier ?? VirtualCardTier.unknown;
    final tierPalette = _tierPalette(tier);

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x2E0F1B2D),
                blurRadius: 32,
                offset: Offset(0, 12),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 60,
                color: header,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    _InstitutionLogo(textColor: Colors.white),
                    const Spacer(),
                    _ClubHeaderLogo(
                      logoUrl: card.clubLogoUrl,
                      fallbackAsset: _clubFallbackAsset(card),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _IdentitySummary(
                        card: card,
                        tierColor: tierPalette.border,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        onPhotoTap: onPhotoTap,
                      ),
                      const SizedBox(height: 16),
                      Divider(color: divider, height: 1),
                      const SizedBox(height: 14),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Center(
                            child: card.canShowQr
                                ? _QrHero(
                                    card: card,
                                    onTap: onShowQr,
                                  )
                                : _QrUnavailableState(
                                    card: card,
                                    onRefresh: onRefresh,
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: TextButton.icon(
                          key: const Key('virtual-card-fullscreen-action'),
                          onPressed: card.canShowQr ? onShowQr : onRefresh,
                          icon:
                              const Icon(Icons.open_in_full_outlined, size: 18),
                          label: Text(
                            card.canShowQr
                                ? 'virtual_card.show_fullscreen'.tr()
                                : 'virtual_card.retry'.tr(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Divider(color: divider, height: 1),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              card.cardIdShort == null ||
                                      card.cardIdShort!.isEmpty
                                  ? 'virtual_card.id_missing'.tr()
                                  : '${'virtual_card.id_prefix'.tr()} ${card.cardIdShort}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.4,
                                color: textTertiary,
                              ),
                            ),
                          ),
                          if (tier != VirtualCardTier.unknown)
                            _TierBadge(
                              tier: tier,
                              color: tierPalette.badge,
                              textColor: tierPalette.badgeText,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (card.isOffline)
          Positioned(
            top: 14,
            left: 14,
            right: 14,
            child: _StatusBanner(
              key: const Key('virtual-card-offline-banner'),
              icon: Icons.wifi_off_outlined,
              text: 'virtual_card.offline_banner'.tr(),
            ),
          ),
        if (card.isInactive)
          Positioned.fill(
            child: Container(
              key: const Key('virtual-card-inactive-overlay'),
              decoration: BoxDecoration(
                color: const Color(0x33C53D3D),
                borderRadius: BorderRadius.circular(24),
              ),
              alignment: Alignment.center,
              padding: const EdgeInsets.all(24),
              child: Text(
                'virtual_card.inactive_message'.tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _InstitutionLogo extends StatelessWidget {
  const _InstitutionLogo({required this.textColor});

  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/img/LogoSACDIA.png',
          width: 30,
          height: 30,
          fit: BoxFit.contain,
        ),
        const SizedBox(width: 10),
        Text(
          'SACDIA',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
          ),
        ),
      ],
    );
  }
}

class _ClubHeaderLogo extends StatelessWidget {
  const _ClubHeaderLogo({
    required this.logoUrl,
    required this.fallbackAsset,
  });

  final String? logoUrl;
  final String fallbackAsset;

  @override
  Widget build(BuildContext context) {
    final image = logoUrl?.trim().isNotEmpty == true
        ? CachedNetworkImage(
            imageUrl: logoUrl!,
            width: 34,
            height: 34,
            fit: BoxFit.contain,
            errorWidget: (_, __, ___) => Image.asset(
              fallbackAsset,
              width: 34,
              height: 34,
              fit: BoxFit.contain,
            ),
          )
        : Image.asset(
            fallbackAsset,
            width: 34,
            height: 34,
            fit: BoxFit.contain,
          );

    return Container(
      width: 44,
      height: 44,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: image,
    );
  }
}

class _IdentitySummary extends StatelessWidget {
  const _IdentitySummary({
    required this.card,
    required this.tierColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.onPhotoTap,
  });

  final VirtualCard card;
  final Color tierColor;
  final Color textPrimary;
  final Color textSecondary;
  final VoidCallback onPhotoTap;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = card.photoUrl?.trim().isNotEmpty == true;
    final club = card.clubName?.trim();
    final section = card.sectionName?.trim();
    final memberSince = card.memberSince == null
        ? null
        : DateFormat.yMMMM(context.locale.toString())
            .format(card.memberSince!.toLocal());

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: hasPhoto ? onPhotoTap : null,
          child: Semantics(
            label: 'virtual_card.photo_alt'.tr(
              namedArgs: {'name': card.fullName},
            ),
            child: _Avatar(
              photoUrl: card.photoUrl,
              fullName: card.fullName,
              tierColor: tierColor,
              size: 86,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                card.fullName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                  height: 1.08,
                  letterSpacing: -0.35,
                ),
              ),
              if ((card.roleLabel ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  card.roleLabel!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: textSecondary,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
              if (club != null && club.isNotEmpty) ...[
                const SizedBox(height: 8),
                _InlineInfo(
                  label: 'virtual_card.club_label'.tr(),
                  value: club,
                  color: textSecondary,
                ),
              ],
              if (section != null && section.isNotEmpty) ...[
                const SizedBox(height: 4),
                _InlineInfo(
                  label: 'virtual_card.section_label'.tr(),
                  value: section,
                  color: textSecondary,
                ),
              ],
              if (memberSince != null) ...[
                const SizedBox(height: 4),
                _InlineInfo(
                  label: 'virtual_card.member_since_label'.tr(),
                  value: memberSince,
                  color: textSecondary,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.photoUrl,
    required this.fullName,
    required this.tierColor,
    this.size = 124,
  });

  final String? photoUrl;
  final String fullName;
  final Color tierColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initials = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part.characters.first.toUpperCase())
        .join();

    final hasPhoto = photoUrl?.trim().isNotEmpty == true;
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: tierColor, width: 4),
      ),
      child: ClipOval(
        child: hasPhoto
            ? CachedNetworkImage(
                imageUrl: photoUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) =>
                    _Placeholder(initials: initials, size: size),
                errorWidget: (_, __, ___) =>
                    _Placeholder(initials: initials, size: size),
              )
            : _Placeholder(initials: initials, size: size),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.initials, required this.size});

  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFECEFF5),
      alignment: Alignment.center,
      child: Text(
        initials.isEmpty ? '·' : initials,
        style: TextStyle(
          fontSize: size * 0.27,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF0F1B2D),
        ),
      ),
    );
  }
}

class _InlineInfo extends StatelessWidget {
  const _InlineInfo({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '${label.toUpperCase()}: ',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          TextSpan(text: value),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 11,
        height: 1.1,
        color: color,
        letterSpacing: 0.35,
      ),
    );
  }
}

class _QrHero extends StatelessWidget {
  const _QrHero({
    required this.card,
    required this.onTap,
  });

  final VirtualCard card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const Key('virtual-card-qr-preview'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Hero(
        tag: 'virtual-card-qr-${card.userId}',
        transitionOnUserGestures: true,
        flightShuttleBuilder: (
          context,
          animation,
          direction,
          fromContext,
          toContext,
        ) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );

          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
              child: direction == HeroFlightDirection.push
                  ? toContext.widget
                  : fromContext.widget,
            ),
          );
        },
        child: VirtualCardQrTile(
          data: card.qrToken!,
          maxSize: 148,
          padding: 10,
          borderRadius: 18,
        ),
      ),
    );
  }
}

class _QrUnavailableState extends StatelessWidget {
  const _QrUnavailableState({
    required this.card,
    required this.onRefresh,
  });

  final VirtualCard card;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final expired = card.isExpired;
    return Container(
      width: 160,
      height: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5F8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E8EE)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          HugeIcon(
            icon: expired
                ? HugeIcons.strokeRoundedRefresh
                : HugeIcons.strokeRoundedQrCode,
            color: const Color(0xFF9099AB),
            size: 34,
          ),
          const SizedBox(height: 10),
          Text(
            expired
                ? 'virtual_card.qr_expired'.tr()
                : 'virtual_card.qr_unavailable'.tr(),
            key: Key(
              expired
                  ? 'virtual-card-qr-expired'
                  : 'virtual-card-qr-unavailable',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF5A6378),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: onRefresh,
            child: Text('virtual_card.retry'.tr()),
          ),
        ],
      ),
    );
  }
}

class _TierBadge extends StatelessWidget {
  const _TierBadge({
    required this.tier,
    required this.color,
    required this.textColor,
  });

  final VirtualCardTier tier;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.emoji_events_outlined, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            tier.labelKey.tr().toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: textColor,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    super.key,
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xEE0F1B2D),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TierPalette {
  const _TierPalette({
    required this.border,
    required this.badge,
    required this.badgeText,
  });

  final Color border;
  final Color badge;
  final Color badgeText;
}

_TierPalette _tierPalette(VirtualCardTier tier) {
  return switch (tier) {
    VirtualCardTier.bronze => const _TierPalette(
        border: Color(0xFFA86E3D),
        badge: Color(0xFFA86E3D),
        badgeText: Colors.white,
      ),
    VirtualCardTier.silver => const _TierPalette(
        border: Color(0xFFA8B0BD),
        badge: Color(0xFFA8B0BD),
        badgeText: Color(0xFF0F1B2D),
      ),
    VirtualCardTier.gold => const _TierPalette(
        border: Color(0xFFD4AF37),
        badge: Color(0xFFD4AF37),
        badgeText: Color(0xFF0F1B2D),
      ),
    VirtualCardTier.platinum => const _TierPalette(
        border: Color(0xFF5DD9C8),
        badge: Color(0xFF5DD9C8),
        badgeText: Color(0xFF0F1B2D),
      ),
    VirtualCardTier.diamond => const _TierPalette(
        border: Color(0xFFB0E0FF),
        badge: Color(0xFFC5A6FF),
        badgeText: Color(0xFF0F1B2D),
      ),
    VirtualCardTier.unknown => const _TierPalette(
        border: Color(0xFF9099AB),
        badge: Color(0xFFE5E8EE),
        badgeText: Color(0xFF0F1B2D),
      ),
  };
}

String _clubFallbackAsset(VirtualCard card) {
  final source = '${card.clubName ?? ''} ${card.roleCode ?? ''}'.toLowerCase();
  if (source.contains('avent')) {
    return 'assets/img/logo_aventureros_color.png';
  }
  if (source.contains('guia') || source.contains('mayor')) {
    return 'assets/img/logo-guias-mayores.png';
  }
  if (source.contains('conq') || source.contains('conquist')) {
    return 'assets/img/logo_conquistadores_color.png';
  }
  return 'assets/img/logo_ave.png';
}
