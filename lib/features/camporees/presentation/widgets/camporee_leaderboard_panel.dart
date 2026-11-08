import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:sacdia_app/core/widgets/sac_settings.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee_leaderboard.dart';
import 'package:sacdia_app/features/camporees/domain/utils/camporee_score_format.dart';

/// Official standings as a grouped list: the top three with a progress bar,
/// the user's own section highlighted, and the rest one tap away.
///
/// Club roles get only their own sections (no positions, no other clubs), so
/// the panel turns into "your section's score" and drops the ranking UI.
class CamporeeLeaderboardPanel extends StatefulWidget {
  final AsyncValue<CamporeeLeaderboard> leaderboardAsync;
  final VoidCallback onRetry;

  /// Highlights this section's row ("Tu sección").
  final int? ownSectionId;

  const CamporeeLeaderboardPanel({
    super.key,
    required this.leaderboardAsync,
    required this.onRetry,
    this.ownSectionId,
  });

  @override
  State<CamporeeLeaderboardPanel> createState() =>
      _CamporeeLeaderboardPanelState();
}

class _CamporeeLeaderboardPanelState extends State<CamporeeLeaderboardPanel> {
  static const int _preview = 3;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    // Until the data arrives, keep the ranking wording only if it was a full
    // ranking before (refresh); a first load uses the neutral title.
    final fullRanking = widget.leaderboardAsync.value?.isFullRanking ?? true;
    final children = widget.leaderboardAsync.when<List<Widget>>(
      loading: () => const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 18),
          child: Center(child: SacLoadingSmall()),
        ),
      ],
      error: (_, __) => [
        _MessageRow(
          icon: HugeIcons.strokeRoundedAlert02,
          iconColor: c.warning,
          text: 'camporees.detail.leaderboard_error'.tr(),
          trailing: SacButton.text(
            text: 'camporees.section_registration.retry'.tr(),
            onPressed: widget.onRetry,
          ),
        ),
      ],
      data: (leaderboard) {
        final rows = leaderboard.rows;
        if (rows.isEmpty) {
          return [
            _MessageRow(
              icon: HugeIcons.strokeRoundedAward01,
              iconColor: c.textTertiary,
              text: leaderboard.isFullRanking
                  ? 'camporees.detail.leaderboard_empty'.tr()
                  : 'camporees.detail.leaderboard_own_empty'.tr(),
            ),
          ];
        }
        if (!leaderboard.isFullRanking) {
          return [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const SacSettingsDivider(),
              _LeaderboardRowTile(row: rows[i], own: false, accentBar: true),
            ],
          ];
        }
        // Keep the user's section visible even when it is not in the top 3.
        final shown = _expanded || rows.length <= _preview
            ? rows
            : [
                ...rows.take(_preview),
                ...rows.skip(_preview).where(
                      (row) => row.clubSectionId == widget.ownSectionId,
                    ),
              ];
        return [
          for (var i = 0; i < shown.length; i++) ...[
            if (i > 0) const SacSettingsDivider(),
            _LeaderboardRowTile(
              row: shown[i],
              own: shown[i].clubSectionId == widget.ownSectionId,
            ),
          ],
          if (rows.length > _preview) ...[
            const SacSettingsDivider(),
            SacInkWell(
              key: const Key('camporee-leaderboard-toggle'),
              onTap: () => setState(() => _expanded = !_expanded),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _expanded
                              ? 'camporees.detail.leaderboard_less'.tr()
                              : 'camporees.detail.leaderboard_all'.tr(
                                  namedArgs: {'count': '${rows.length}'},
                                ),
                          style: TextStyle(
                            fontSize: SacFontSize.bodyMedium,
                            fontWeight: FontWeight.w600,
                            color: SacAccent.of(context).color,
                          ),
                        ),
                      ),
                      AnimatedRotation(
                        turns: _expanded ? 0.25 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedArrowRight01,
                          size: 16,
                          color: c.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ];
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SacSettingsGroup(
          key: const Key('camporee-leaderboard-group'),
          title: (fullRanking
                  ? 'camporees.detail.leaderboard_title'
                  : 'camporees.detail.leaderboard_own_title')
              .tr()
              .toUpperCase(),
          children: children,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: Text(
            (fullRanking
                    ? 'camporees.detail.leaderboard_subtitle'
                    : 'camporees.detail.leaderboard_own_subtitle')
                .tr(),
            style: TextStyle(
              fontSize: SacFontSize.bodySmall,
              color: c.textTertiary,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _LeaderboardRowTile extends StatelessWidget {
  final CamporeeLeaderboardRow row;
  final bool own;

  /// Paints the progress bar with the accent even when the row is not
  /// highlighted (the own-sections view has nothing to compare against).
  final bool accentBar;

  const _LeaderboardRowTile({
    required this.row,
    required this.own,
    this.accentBar = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final accent = SacAccent.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final club = row.clubName?.trim().isNotEmpty == true
        ? row.clubName!
        : 'camporees.detail.leaderboard_unknown_club'.tr();
    final section = row.sectionName?.trim().isNotEmpty == true
        ? row.sectionName!
        : 'camporees.detail.leaderboard_section_fallback'.tr(
            namedArgs: {'id': '${row.clubSectionId}'},
          );
    final awarded = formatCamporeeScoreNumber(row.totalAwardedPoints);
    final max = formatCamporeeScoreNumber(row.totalMaxPoints);
    final percent = formatCamporeeScoreNumber(row.percentage);
    final fill = (row.percentage / 100).clamp(0.0, 1.0);
    final rankColor = own ? accent.color : c.textSecondary;
    final rank = row.rank;

    return Container(
      color: own
          ? (dark
              ? Color.alphaBlend(
                  accent.color.withValues(alpha: 0.16), c.surface)
              : accent.surface)
          : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          if (rank != null) ...[
            SizedBox(
              width: 26,
              child: Text(
                '$rank',
                style: TextStyle(
                  fontSize: SacFontSize.titleMedium,
                  fontWeight: FontWeight.w700,
                  color: rankColor,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        club,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: SacFontSize.bodyMedium,
                          fontWeight: FontWeight.w600,
                          color: c.text,
                        ),
                      ),
                    ),
                    if (own) ...[
                      const SizedBox(width: 6),
                      SacBadge(
                        label: 'camporees.detail.leaderboard_yours'.tr(),
                        variant: SacBadgeVariant.primary,
                      ),
                    ],
                  ],
                ),
                Text(
                  section,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: SacFontSize.bodySmall,
                    color: c.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusHairline),
                  child: LinearProgressIndicator(
                    value: fill,
                    minHeight: 4,
                    backgroundColor: c.surfaceVariant,
                    color: own || accentBar ? accent.color : c.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$awarded / $max',
                style: TextStyle(
                  fontSize: SacFontSize.bodyMedium,
                  fontWeight: FontWeight.w700,
                  color: c.text,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                '$percent%',
                style: TextStyle(
                  fontSize: SacFontSize.bodySmall,
                  color: c.textSecondary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MessageRow extends StatelessWidget {
  final HugeIconData icon;
  final Color iconColor;
  final String text;
  final Widget? trailing;

  const _MessageRow({
    required this.icon,
    required this.iconColor,
    required this.text,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          HugeIcon(icon: icon, size: 20, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: SacFontSize.bodyMedium,
                color: context.sac.textSecondary,
                height: 1.35,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
