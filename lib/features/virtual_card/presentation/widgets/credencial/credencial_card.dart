import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/core/widgets/sac_profile_image.dart';

import '../../../../../core/utils/blood_type.dart';
import 'credencial_tokens.dart';
import 'credencial_view_model.dart';
import 'live_clock.dart';

/// What the QR on the card can do right now.
enum CredencialQrState {
  /// A valid code: tapping it opens the full-screen QR.
  ready,

  /// The code expired: tapping it asks for a new one.
  expired,

  /// There is no code (no token yet).
  unavailable,

  /// The membership is not active: no code and a grey header.
  suspended,
}

/// The credential: the section header (its only brand colors) and a white zone
/// with the QR, which is what members show every day. The data rows only
/// appear in the shared image ([showDetails]); on screen they live in a
/// group below the card.
class CredencialCard extends StatelessWidget {
  const CredencialCard({
    super.key,
    required this.vm,
    this.qrState = CredencialQrState.ready,
    this.onQrTap,
    this.qrSize = 176,
    this.showDetails = false,
    this.heroTag,
  });

  final CredencialViewModel vm;
  final CredencialQrState qrState;
  final VoidCallback? onQrTap;
  final double qrSize;

  /// Adds club, field, union, year and blood type inside the card, for the
  /// image that is shared.
  final bool showDetails;

  /// Hero tag shared with [CredencialQrFullscreen].
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final sec = Sec.of(vm.seccion);
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(CredencialTokens.rImmersive),
        border: Border.all(color: c.border),
        boxShadow: [
          BoxShadow(
            blurRadius: 22,
            offset: const Offset(0, 6),
            color: c.shadow,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(CredencialTokens.rImmersive),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              vm: vm,
              sec: sec,
              suspended: qrState == CredencialQrState.suspended,
            ),
            _QrZone(
              vm: vm,
              sec: sec,
              qrState: qrState,
              qrSize: qrSize,
              onQrTap: onQrTap,
              showDetails: showDetails,
              heroTag: heroTag,
            ),
          ],
        ),
      ),
    );
  }
}

/// Greyscale matrix for the header of a suspended credential.
const _greyscale = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0, //
]);

class _Header extends StatelessWidget {
  const _Header({required this.vm, required this.sec, required this.suspended});

  final CredencialViewModel vm;
  final Sec sec;
  final bool suspended;

  @override
  Widget build(BuildContext context) {
    final subtitle = vm.identitySubtitle(
      currentClassLabel: 'virtual_card.current_class_label'.tr(),
      sectionDisplayName: sec.label,
    );
    final header = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [sec.primary, sec.primaryDark],
          stops: const [0.0, 0.8],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -36,
            top: -28,
            child: ExcludeSemantics(
              child: Opacity(
                opacity: 0.12,
                child: Transform.rotate(
                  angle: -0.21,
                  child: Image.asset(
                    sec.logo,
                    width: 170,
                    height: 170,
                    cacheWidth: 510,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Image.asset(
                      sec.logo,
                      width: 28,
                      height: 28,
                      cacheWidth: 84,
                      excludeFromSemantics: true,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        sec.label.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: SacFontSize.labelSmall,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.9,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    _StatusPill(suspended: suspended),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _Avatar(vm: vm),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vm.nombre,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: SacFontSize.headlineMedium,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                              height: 1.15,
                              color: Colors.white,
                            ),
                          ),
                          if (subtitle.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: SacFontSize.bodyMedium,
                                height: 1.3,
                                color: Colors.white.withValues(alpha: 0.88),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return suspended
        ? ColorFiltered(colorFilter: _greyscale, child: header)
        : header;
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.suspended});

  final bool suspended;

  @override
  Widget build(BuildContext context) {
    final label = suspended
        ? 'virtual_card.status_suspended'.tr()
        : 'virtual_card.status_active'.tr();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(CredencialTokens.rChip),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: suspended
                  ? CredencialTokens.suspendedDot
                  : CredencialTokens.activeDot,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: SacFontSize.bodySmall,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.vm});

  final CredencialViewModel vm;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = vm.fotoUrl != null && vm.fotoUrl!.isNotEmpty;
    final initials = Container(
      color: Colors.white.withValues(alpha: 0.22),
      alignment: Alignment.center,
      child: Text(
        vm.iniciales,
        style: const TextStyle(
          fontSize: SacFontSize.headlineSmall,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.55),
          width: 2,
        ),
      ),
      child: ClipOval(
        child: hasPhoto
            ? SacProfileImage(
                imageUrl: vm.fotoUrl!,
                fit: BoxFit.cover,
                memCacheWidth: 168,
                errorWidget: (_, __, ___) => initials,
              )
            : initials,
      ),
    );
  }
}

class _QrZone extends StatelessWidget {
  const _QrZone({
    required this.vm,
    required this.sec,
    required this.qrState,
    required this.qrSize,
    required this.onQrTap,
    required this.showDetails,
    required this.heroTag,
  });

  final CredencialViewModel vm;
  final Sec sec;
  final CredencialQrState qrState;
  final double qrSize;
  final VoidCallback? onQrTap;
  final bool showDetails;
  final String? heroTag;

  String get _captionKey {
    switch (qrState) {
      case CredencialQrState.ready:
        return 'virtual_card.qr_hint';
      case CredencialQrState.expired:
        return 'virtual_card.qr_tap_renew';
      case CredencialQrState.unavailable:
      case CredencialQrState.suspended:
        return 'virtual_card.qr_not_available';
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final mono = TextStyle(
      fontSize: SacFontSize.labelSmall,
      fontFamily: 'monospace',
      color: c.textTertiary,
    );
    Widget qr = _QrTile(vm: vm, sec: sec, qrState: qrState, size: qrSize);
    if (heroTag != null && qrState == CredencialQrState.ready) {
      qr = Hero(tag: heroTag!, child: qr);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
      child: Column(
        children: [
          Semantics(
            button: onQrTap != null,
            label: 'virtual_card.qr_alt'.tr(),
            child: GestureDetector(onTap: onQrTap, child: qr),
          ),
          const SizedBox(height: 10),
          Text(
            _captionKey.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: SacFontSize.bodyMedium,
              color: c.textSecondary,
              height: 1.35,
            ),
          ),
          if (showDetails) ...[
            const SizedBox(height: 12),
            _Details(vm: vm),
          ],
          const SizedBox(height: 12),
          Divider(height: 1, thickness: 1, color: c.border),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: Text(
                  vm.folio,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: mono,
                ),
              ),
              const SizedBox(width: 8),
              LiveClock(style: mono),
            ],
          ),
        ],
      ),
    );
  }
}

class _QrTile extends StatelessWidget {
  const _QrTile({
    required this.vm,
    required this.sec,
    required this.qrState,
    required this.size,
  });

  final CredencialViewModel vm;
  final Sec sec;
  final CredencialQrState qrState;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final hasCode = vm.qrData.isNotEmpty;
    final Widget code = hasCode
        ? QrImageView(
            data: vm.qrData,
            size: size,
            padding: EdgeInsets.zero,
            backgroundColor: Colors.white,
            eyeStyle: QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: sec.primaryDark,
            ),
            dataModuleStyle: QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: sec.primaryDark,
            ),
          )
        : SizedBox(
            width: size,
            height: size,
            child: Center(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedQrCode01,
                size: 48,
                color: c.textTertiary,
              ),
            ),
          );

    final blocked = qrState != CredencialQrState.ready && hasCode;
    final HugeIconData? overlayIcon = switch (qrState) {
      CredencialQrState.expired => HugeIcons.strokeRoundedRefresh,
      CredencialQrState.suspended => HugeIcons.strokeRoundedSquareLock02,
      _ => null,
    };

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(color: c.border),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (blocked)
            Opacity(
              opacity: 0.5,
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: code,
              ),
            )
          else
            code,
          if (blocked && overlayIcon != null)
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(blurRadius: 10, color: c.shadow),
                ],
              ),
              child: Center(
                child: HugeIcon(
                  icon: overlayIcon,
                  size: 22,
                  color: CredencialTokens.overlayIcon,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Data rows inside the card, only for the shared image.
class _Details extends StatelessWidget {
  const _Details({required this.vm});

  final CredencialViewModel vm;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final blood = BloodType.localizedDisplayFor(
      vm.tipoSangre,
      languageCode: context.locale.languageCode,
    );
    final rows = <(String, String)>[
      ('virtual_card.field_club'.tr(), vm.club),
      ('virtual_card.field_local_field'.tr(), vm.campoLocal),
      ('virtual_card.field_union'.tr(), vm.unionNombre),
      ('virtual_card.field_year'.tr(), vm.anioEclesiastico),
      if (blood != null && blood.isNotEmpty)
        ('virtual_card.field_blood'.tr(), blood),
    ];
    return Column(
      children: [
        for (final (label, value) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: SacFontSize.bodyMedium,
                    color: c.textSecondary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    value.trim().isEmpty ? '—' : value.trim(),
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: SacFontSize.bodyMedium,
                      fontWeight: FontWeight.w600,
                      color: c.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
