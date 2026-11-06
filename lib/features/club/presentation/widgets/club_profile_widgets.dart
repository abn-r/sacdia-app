import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/club_type.dart';
import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/icon_helper.dart';
import '../../../../core/widgets/sac_network_image.dart';
import '../../../../core/widgets/sac_pressable.dart';
import '../../domain/entities/club_info.dart';

/// Club data a director can fill in. Name and type come from the
/// organization and are not editable here.
enum ClubField { location, phone, email, website }

String? _clean(String? value) {
  final trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}

extension ClubSectionProfileX on ClubSection {
  bool get hasCoordinates => lat != null && long != null;

  /// The section with the club's own coordinates when it has none.
  ///
  /// Location can live on the club (`clubs.coordinates`) rather than on the
  /// section, so the ficha falls back to it. Only for display: the editor
  /// keeps the section as it is, so saving never copies it silently.
  ClubSection withClubLocation(ClubInfo? club) {
    if (hasCoordinates || club?.lat == null || club?.long == null) return this;
    return ClubSection(
      id: id,
      mainClubId: mainClubId,
      clubTypeId: clubTypeId,
      clubTypeName: clubTypeName,
      phone: phone,
      email: email,
      website: website,
      logoUrl: logoUrl,
      address: address,
      lat: club!.lat,
      long: club.long,
      active: active,
    );
  }

  bool get hasLocation => hasCoordinates || _clean(address) != null;

  String? get phoneValue => _clean(phone);
  String? get emailValue => _clean(email);
  String? get websiteValue => _clean(website);
  String? get logoValue => _clean(logoUrl);

  /// Fields the director has not registered yet, in display order.
  List<ClubField> get missingFields => [
        if (!hasLocation) ClubField.location,
        if (phoneValue == null) ClubField.phone,
        if (emailValue == null) ClubField.email,
        if (websiteValue == null) ClubField.website,
      ];
}

/// Logo, name and club type, centered like a contact card.
class ClubProfileHero extends StatelessWidget {
  const ClubProfileHero({
    super.key,
    required this.name,
    required this.clubTypeName,
    this.logoUrl,
  });

  final String name;
  final String clubTypeName;
  final String? logoUrl;

  static const double _logoSize = 88;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final typeAsset = clubLogoAssetFromName(clubTypeName);

    Widget fallback() => typeAsset != null
        ? Image.asset(typeAsset, fit: BoxFit.contain)
        : Center(
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedBackpack03,
              size: 36,
              color: c.textTertiary,
            ),
          );

    final url = logoUrl;
    return Column(
      children: [
        Container(
          key: const ValueKey('club-hero-logo'),
          width: _logoSize,
          height: _logoSize,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusLG),
            border: Border.all(color: c.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: url != null
              ? SacNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.contain,
                  memCacheWidth: 264,
                  memCacheHeight: 264,
                  errorWidget: (_, __, ___) => fallback(),
                )
              : fallback(),
        ),
        const SizedBox(height: 14),
        if (name.isNotEmpty)
          Text(
            name,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: SacFontSize.displaySmall,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
              height: 1.15,
              color: c.text,
            ),
          ),
        if (clubTypeName.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'club.profile.club_of'.tr(namedArgs: {'type': clubTypeName}),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: SacFontSize.bodyMedium,
              color: c.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

/// Director-only prompt with the count of missing fields and «Completar».
class ClubMissingDataPrompt extends StatelessWidget {
  const ClubMissingDataPrompt({
    super.key,
    required this.missingCount,
    required this.onComplete,
  });

  final int missingCount;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final ink = c.onWarningContainer;
    return Container(
      key: const ValueKey('club-missing-prompt'),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: c.warningContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
      ),
      child: Row(
        children: [
          HugeIcon(
              icon: HugeIcons.strokeRoundedAlertCircle, size: 20, color: ink),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'club.profile.missing_title'.plural(missingCount),
                  style: TextStyle(
                    fontSize: SacFontSize.titleSmall,
                    fontWeight: FontWeight.w700,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'club.profile.missing_body'.tr(),
                  style: TextStyle(fontSize: SacFontSize.bodySmall, color: ink),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          TextButton(
            key: const ValueKey('club-missing-complete'),
            onPressed: onComplete,
            style: TextButton.styleFrom(
              foregroundColor: ink,
              minimumSize: const Size(44, 44),
              textStyle: const TextStyle(
                fontSize: SacFontSize.titleSmall,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: Text('club.profile.complete'.tr()),
          ),
        ],
      ),
    );
  }
}

/// Eyebrow label + one surface card holding the rows of a section.
class ClubInfoGroup extends StatelessWidget {
  const ClubInfoGroup({
    super.key,
    required this.label,
    required this.children,
    this.header,
  });

  final String label;

  /// Drawn edge to edge at the top of the card (the map preview).
  final Widget? header;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(Divider(height: 1, thickness: 1, indent: 64, color: c.border));
      }
      rows.add(children[i]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: SacFontSize.labelSmall,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: c.textTertiary,
            ),
          ),
        ),
        Material(
          color: c.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            side: BorderSide(color: c.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (header != null) ...[
                header!,
                Divider(height: 1, thickness: 1, color: c.border),
              ],
              ...rows,
            ],
          ),
        ),
      ],
    );
  }
}

/// One row of the ficha: icon, label over value, trailing affordance.
///
/// A null [value] means «not registered»: the row shows «Sin registrar» and
/// an «Agregar» action. Only directors get those rows; members never see
/// empty fields.
class ClubInfoRow extends StatelessWidget {
  const ClubInfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.trailingIcon = HugeIcons.strokeRoundedArrowUpRight01,
    this.actionHint,
  });

  final HugeIconData icon;
  final String label;
  final String? value;
  final VoidCallback onTap;
  final HugeIconData trailingIcon;

  /// What a tap does, read by screen readers («Llamar», «Cómo llegar»).
  final String? actionHint;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final accent = SacAccent.of(context);
    final empty = value == null;

    return Semantics(
      button: true,
      label: '$label. ${value ?? 'club.profile.not_registered'.tr()}',
      hint: empty ? 'common.add'.tr() : actionHint,
      excludeSemantics: true,
      child: SacInkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: empty ? c.surfaceVariant : accent.light,
                    shape: BoxShape.circle,
                  ),
                  child: HugeIcon(
                    icon: icon,
                    size: 18,
                    color: empty ? c.textTertiary : accent.color,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: SacFontSize.bodySmall,
                          color: c.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        value ?? 'club.profile.not_registered'.tr(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: SacFontSize.titleMedium,
                          fontWeight: empty ? FontWeight.w400 : FontWeight.w500,
                          color: empty ? c.textTertiary : c.text,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (empty)
                  Text(
                    'common.add'.tr(),
                    style: TextStyle(
                      fontSize: SacFontSize.titleSmall,
                      fontWeight: FontWeight.w600,
                      color: accent.color,
                    ),
                  )
                else
                  HugeIcon(icon: trailingIcon, size: 18, color: c.textTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Static map preview with a pin. Not interactive: the rows below open maps.
class ClubMapPreview extends StatelessWidget {
  const ClubMapPreview({
    super.key,
    required this.lat,
    required this.long,
    required this.onTap,
  });

  final double lat;
  final double long;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final center = LatLng(lat, long);
    return SizedBox(
      height: 148,
      child: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: center, zoom: 15),
              markers: {
                Marker(markerId: const MarkerId('club'), position: center),
              },
              zoomControlsEnabled: false,
              scrollGesturesEnabled: false,
              rotateGesturesEnabled: false,
              tiltGesturesEnabled: false,
              zoomGesturesEnabled: false,
              myLocationButtonEnabled: false,
              mapToolbarEnabled: false,
              compassEnabled: false,
              // liteModeEnabled solo funciona en Android; en iOS deja el mapa en blanco.
            ),
          ),
          Material(
            type: MaterialType.transparency,
            child: SacInkWell(onTap: onTap, child: const SizedBox.expand()),
          ),
        ],
      ),
    );
  }
}
