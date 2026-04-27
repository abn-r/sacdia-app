import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../domain/entities/virtual_card.dart';

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
    final textPrimary = isDark ? const Color(0xFFF4F7FB) : const Color(0xFF0F1B2D);
    final textSecondary = isDark ? const Color(0xFFA0AABF) : const Color(0xFF5A6378);
    final textTertiary = isDark ? const Color(0xFF5A6378) : const Color(0xFF9099AB);
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
                      Center(
                        child: GestureDetector(
                          onTap: card.photoUrl?.trim().isNotEmpty == true
                              ? onPhotoTap
                              : null,
                          child: Semantics(
                            label: 'virtual_card.photo_alt'.tr(
                              namedArgs: {'name': card.fullName},
                            ),
                            child: _Avatar(
                              photoUrl: card.photoUrl,
                              fullName: card.fullName,
                              tierColor: tierPalette.border,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        card.fullName,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                          letterSpacing: -0.4,
                        ),
                      ),
                      if ((card.roleLabel ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          card.roleLabel!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: textSecondary,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      Divider(color: divider, height: 1),
                      const SizedBox(height: 16),
                      _MetaRow(
                        label: 'virtual_card.club_label'.tr(),
                        value: card.clubName,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                      ),
                      if ((card.sectionName ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 14),
                        _MetaRow(
                          label: 'virtual_card.section_label'.tr(),
                          value: card.sectionName,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                        ),
                      ],
                      if (card.memberSince != null) ...[
                        const SizedBox(height: 14),
                        _MetaRow(
                          label: 'virtual_card.member_since_label'.tr(),
                          value: DateFormat.yMMMM(context.locale.toString())
                              .format(card.memberSince!.toLocal()),
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                        ),
                      ],
                      const SizedBox(height: 18),
                      Divider(color: divider, height: 1),
                      const SizedBox(height: 16),
                      Expanded(
                        child: Center(
                          child: card.canShowQr
                              ? GestureDetector(
                                  onTap: onShowQr,
                                  child: Hero(
                                    tag: 'virtual-card-qr-${card.userId}',
                                    child: _QrPreview(card: card),
                                  ),
                                )
                              : _QrUnavailableState(
                                  card: card,
                                  onRefresh: onRefresh,
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: TextButton.icon(
                          key: const Key('virtual-card-fullscreen-action'),
                          onPressed: card.canShowQr ? onShowQr : onRefresh,
                          icon: const Icon(Icons.open_in_full_outlined, size: 18),
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
                              card.cardIdShort == null || card.cardIdShort!.isEmpty
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

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.photoUrl,
    required this.fullName,
    required this.tierColor,
  });

  final String? photoUrl;
  final String fullName;
  final Color tierColor;

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
      width: 124,
      height: 124,
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
                placeholder: (_, __) => _Placeholder(initials: initials),
                errorWidget: (_, __, ___) => _Placeholder(initials: initials),
              )
            : _Placeholder(initials: initials),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFECEFF5),
      alignment: Alignment.center,
      child: Text(
        initials.isEmpty ? '·' : initials,
        style: const TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w800,
          color: Color(0xFF0F1B2D),
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.label,
    required this.value,
    required this.textPrimary,
    required this.textSecondary,
  });

  final String label;
  final String? value;
  final Color textPrimary;
  final Color textSecondary;

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            color: textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value!,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: textPrimary,
          ),
        ),
      ],
    );
  }
}

class _QrPreview extends StatelessWidget {
  const _QrPreview({required this.card});

  final VirtualCard card;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      height: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E8EE)),
      ),
      child: Semantics(
        label: 'virtual_card.qr_alt'.tr(),
        child: QrImageView(
          data: card.qrToken!,
          version: QrVersions.auto,
          backgroundColor: Colors.white,
          errorCorrectionLevel: QrErrorCorrectLevel.M,
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
