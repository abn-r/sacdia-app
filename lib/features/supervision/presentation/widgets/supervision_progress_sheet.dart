import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_list_row.dart';
import 'package:sacdia_app/core/widgets/sac_sheet.dart';
import 'package:sacdia_app/core/widgets/status_progress/sac_grouped_section.dart';
import 'package:sacdia_app/features/rankings/presentation/widgets/annual_progress_parts.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_annual_progress.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_format.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_progress_parts.dart';

/// Opens the sheet of one club: its medal filling toward the next one and
/// where its points come from.
void showSupervisionClubProgressSheet(
  BuildContext context,
  SupervisionClubProgress club,
  String clubTypeName,
) {
  showSacSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) =>
        SupervisionClubProgressSheet(club: club, clubTypeName: clubTypeName),
  );
}

class SupervisionClubProgressSheet extends StatelessWidget {
  const SupervisionClubProgressSheet({
    super.key,
    required this.club,
    required this.clubTypeName,
  });

  final SupervisionClubProgress club;
  final String clubTypeName;

  @override
  Widget build(BuildContext context) {
    // Axes group the components; a configuration without axes lists them flat.
    final axes = club.axes.where((axis) => axis.components.isNotEmpty).toList();

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SacSheetGrabber(),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _MedalHeader(club: club, clubTypeName: clubTypeName),
                  if (axes.isNotEmpty)
                    for (var i = 0; i < axes.length; i++)
                      _AxisSection(
                        label: axes[i].label,
                        earned: axes[i].earnedPoints,
                        max: axes[i].maxPoints,
                        color: annualAxisColor(axes[i].key, i),
                        components: axes[i].components,
                      )
                  else if (club.components.isNotEmpty)
                    _AxisSection(
                      label:
                          'supervision.annual_progress.components_title'.tr(),
                      earned: null,
                      max: null,
                      color: annualAxisColor('', 0),
                      components: club.components,
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              16 + MediaQuery.paddingOf(context).bottom,
            ),
            child: SacButton.outline(
              text: 'common.close'.tr(),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Medal of the next tier (grey) filling in color up to the progress made,
/// with the club, the current tier and what is missing.
class _MedalHeader extends StatelessWidget {
  const _MedalHeader({required this.club, required this.clubTypeName});

  final SupervisionClubProgress club;
  final String clubTypeName;

  static const double _medalSize = 76;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final current = club.currentTier;
    final next = club.nextTier;
    final showcase = next ?? current;
    final currentName = current?.name.trim() ?? '';
    final nextName = next?.name.trim() ?? '';
    final toReach = next == null
        ? null
        : (next.pointsToReach ??
            (next.fromPoints - club.currentPoints)
                .clamp(0, double.infinity)
                .toDouble());
    final fraction = next == null || next.fromPoints <= 0
        ? 1.0
        : (club.currentPoints / next.fromPoints).clamp(0.0, 1.0).toDouble();
    final points = 'supervision.annual_progress.points_short'
        .tr(args: [supervisionPoints(context, club.currentPoints)]);
    final title = currentName.isEmpty ? points : '$currentName · $points';
    final eyebrow = [club.clubName, clubTypeName]
        .where((part) => part.trim().isNotEmpty)
        .join(' · ')
        .toUpperCase();

    final Widget status;
    if (next != null && toReach != null && toReach > 0 && nextName.isNotEmpty) {
      final missing = supervisionPoints(context, toReach);
      status = AnnualEmphasisText(
        text: 'supervision.annual_progress.missing_points'
            .tr(args: [missing, nextName]),
        emphasis: missing,
        style: TextStyle(
          fontSize: SacFontSize.bodyMedium,
          height: 1.3,
          color: c.textSecondary,
        ),
      );
    } else if (next == null && current != null) {
      status = Text(
        'supervision.annual_progress.top_tier'.tr(),
        style: TextStyle(
          fontSize: SacFontSize.bodyMedium,
          height: 1.3,
          color: c.textSecondary,
        ),
      );
    } else {
      status = const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Row(
        children: [
          if (showcase != null)
            _MedalFill(tier: showcase, fraction: fraction, size: _medalSize)
          else
            const SupervisionTierMedal(tier: null, size: _medalSize),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: SacFontSize.labelSmall,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                    color: c.textTertiary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: SacFontSize.headlineSmall,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    height: 1.15,
                    color: c.text,
                  ),
                ),
                const SizedBox(height: 4),
                status,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The medal grey underneath and in color from the bottom up to [fraction]
/// (the compact cousin of the club-side hero medal).
class _MedalFill extends StatelessWidget {
  const _MedalFill({
    required this.tier,
    required this.fraction,
    required this.size,
  });

  final SupervisionProgressTier tier;
  final double fraction;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ranking = supervisionRankingTier(tier);
    final isFull = fraction >= 1;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          children: [
            if (!isFull)
              AnnualTierMedal(tier: ranking, size: size, unearned: true),
            Align(
              alignment: Alignment.bottomCenter,
              child: ClipRect(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  heightFactor: fraction,
                  child: AnnualTierMedal(tier: ranking, size: size),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Axes and components ─────────────────────────────────────────────────────

class _AxisSection extends StatelessWidget {
  const _AxisSection({
    required this.label,
    required this.earned,
    required this.max,
    required this.color,
    required this.components,
  });

  final String label;

  /// Null when the group has no axis totals (flat components).
  final double? earned;
  final double? max;
  final Color color;
  final List<SupervisionProgressComponent> components;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final e = earned;
    final m = max;
    return SacGroupedSection(
      label: label,
      dividerIndent: 64,
      action: e == null || m == null
          ? const SizedBox.shrink()
          : Text(
              'supervision.annual_progress.points_of'.tr(args: [
                supervisionPoints(context, e),
                supervisionPoints(context, m),
              ]).toUpperCase(),
              style: TextStyle(
                fontSize: SacFontSize.labelSmall,
                fontWeight: FontWeight.w600,
                color: c.textTertiary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
      children: [
        for (final item in components)
          _ComponentRow(component: item, color: color),
      ],
    );
  }
}

class _ComponentRow extends StatelessWidget {
  const _ComponentRow({required this.component, required this.color});

  final SupervisionProgressComponent component;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return SacListRow(
      leading: _AxisIcon(icon: _iconFor(component.key), color: color),
      title: component.label,
      subtitleWidget: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'supervision.annual_progress.points_of'.tr(
              args: [
                supervisionPoints(context, component.earnedPoints),
                supervisionPoints(context, component.maxPoints),
              ],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: SacFontSize.bodyMedium,
              height: 1.3,
              color: c.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          SupervisionAxisBar(
            fraction: component.progressPercentage / 100,
            color: color,
          ),
        ],
      ),
      trailing: Text(
        supervisionPercent(component.progressPercentage),
        maxLines: 1,
        style: TextStyle(
          fontSize: SacFontSize.titleMedium,
          fontWeight: FontWeight.w600,
          color: c.text,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// Icon of a component by its key (with the aliases the server uses).
HugeIconData _iconFor(String key) {
  final k = key.toLowerCase();
  if (k.contains('folder')) return HugeIcons.strokeRoundedFolder01;
  if (k.contains('financ')) return HugeIcons.strokeRoundedMoney01;
  if (k.contains('camporee')) return HugeIcons.strokeRoundedCampfire;
  if (k.contains('report')) return HugeIcons.strokeRoundedTask01;
  if (k.contains('class') || k.contains('invest')) {
    return HugeIcons.strokeRoundedMortarboard01;
  }
  if (k.contains('activit') || k.contains('event')) {
    return HugeIcons.strokeRoundedCalendar03;
  }
  return HugeIcons.strokeRoundedTarget02;
}

/// Square icon tile tinted with the color of its axis.
class _AxisIcon extends StatelessWidget {
  const _AxisIcon({required this.icon, required this.color});

  final HugeIconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(AppTheme.radiusXS),
        ),
        child: HugeIcon(icon: icon, size: 19, color: color),
      ),
    );
  }
}
