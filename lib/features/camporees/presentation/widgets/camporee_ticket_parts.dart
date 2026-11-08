import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/club_type.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee.dart';
import 'package:sacdia_app/features/camporees/domain/utils/camporee_period.dart';

/// Pieces shared by the camporee ticket in the list and the detail header.

/// Chip text and badge variant for where a camporee stands.
class CamporeeStatus {
  const CamporeeStatus({required this.label, required this.variant});

  final String label;
  final SacBadgeVariant variant;

  factory CamporeeStatus.of(BuildContext context, CamporeeTiming timing) {
    switch (timing.kind) {
      case CamporeeTimingKind.upcoming:
        return CamporeeStatus(
          label: 'camporees.list.timing.in_days'.plural(timing.days),
          variant: SacBadgeVariant.primary,
        );
      case CamporeeTimingKind.ongoing:
        final String label;
        if (timing.totalDays == 1) {
          label = 'camporees.list.timing.today'.tr();
        } else if (timing.endsToday) {
          label = 'camporees.list.timing.ends_today'.tr();
        } else {
          label = 'camporees.list.timing.ongoing'.tr(namedArgs: {
            'day': '${timing.day}',
            'total': '${timing.totalDays}',
          });
        }
        return CamporeeStatus(
          label: label,
          variant: SacBadgeVariant.secondary,
        );
      case CamporeeTimingKind.ended:
        final days = timing.days;
        final String label;
        if (days < 30) {
          label = 'camporees.list.timing.ended_days'.plural(days);
        } else if (days < 365) {
          label = 'camporees.list.timing.ended_months'.plural(days ~/ 30);
        } else {
          label = 'camporees.list.timing.ended_years'.plural(days ~/ 365);
        }
        return CamporeeStatus(label: label, variant: SacBadgeVariant.neutral);
    }
  }
}

/// The club types the camporee is for, as their logos. One logo fills the
/// slot; two or three overlap. Screen readers get the names.
class CamporeeClubLogos extends StatelessWidget {
  final Camporee camporee;
  final bool dimmed;

  const CamporeeClubLogos({
    super.key,
    required this.camporee,
    this.dimmed = false,
    this.size = 44,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    final types = [
      if (camporee.includesAdventurers) ClubType.aventureros,
      if (camporee.includesPathfinders) ClubType.conquistadores,
      if (camporee.includesMasterGuides) ClubType.guiasMayores,
    ];
    final names = [
      if (camporee.includesAdventurers) 'camporees.common.adventurers'.tr(),
      if (camporee.includesPathfinders) 'camporees.common.pathfinders'.tr(),
      if (camporee.includesMasterGuides) 'camporees.common.master_guides'.tr(),
    ];

    final Widget logos;
    if (types.isEmpty) {
      logos = _LogoDisc(size: size, asset: null);
    } else if (types.length == 1) {
      logos = _LogoDisc(size: size, asset: types.first.logoAsset);
    } else {
      // Small discs on a diagonal (two) or a fan (three).
      final small = size * 0.68;
      final step = size - small;
      final offsets = types.length == 2
          ? [Offset.zero, Offset(step, step)]
          : [Offset.zero, Offset(step, 0), Offset(step / 2, step)];
      logos = SizedBox.square(
        dimension: size,
        child: Stack(
          children: [
            for (var i = 0; i < types.length; i++)
              Positioned(
                left: offsets[i].dx,
                top: offsets[i].dy,
                child: _LogoDisc(size: small, asset: types[i].logoAsset),
              ),
          ],
        ),
      );
    }

    return Semantics(
      label: names.join(', '),
      child: ExcludeSemantics(
        child: Opacity(opacity: dimmed ? 0.55 : 1, child: logos),
      ),
    );
  }
}

class _LogoDisc extends StatelessWidget {
  final double size;
  final String? asset;

  const _LogoDisc({required this.size, required this.asset});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.1),
      decoration: BoxDecoration(
        color: c.surface,
        shape: BoxShape.circle,
        border: Border.all(color: c.borderLight),
      ),
      child: asset == null
          ? HugeIcon(
              icon: HugeIcons.strokeRoundedCampfire,
              size: size * 0.5,
              color: c.textTertiary,
            )
          : Image.asset(
              asset!,
              fit: BoxFit.contain,
              cacheWidth: (size * 3).round(),
            ),
    );
  }
}
