import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/animations/motion_tokens.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/icon_helper.dart';
import '../../../../core/widgets/sac_pressable.dart';
import '../../domain/entities/dependent.dart';
import 'dependent_avatar.dart';

/// Status line of a minor's club ("Sin club", "Solicitud pendiente en…").
String dependentClubLabel(DependentClubMembership? membership) {
  if (membership == null) return 'family.club.none'.tr();
  final club = membership.clubName ?? '';
  return switch (membership.status) {
    'active' => 'family.club.active'.tr(namedArgs: {'club': club}),
    'pending' => 'family.club.pending'.tr(namedArgs: {'club': club}),
    'rejected' => 'family.club.rejected'.tr(),
    'expired' => 'family.club.expired'.tr(),
    'cancelled' => 'family.club.cancelled'.tr(),
    _ => 'family.club.none'.tr(),
  };
}

/// One row inside a [SacGroupedSection] of Mi familia: a leading avatar or
/// icon, a title, one line under it and a chevron when it opens something.
class FamilyRow extends StatelessWidget {
  const FamilyRow({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.subtitleSpans,
    this.subtitleColor,
    this.titleColor,
    this.trailing,
    this.onTap,
    this.enabled = true,
    this.showChevron = true,
  });

  final Widget leading;
  final String title;
  final String? subtitle;

  /// Subtitle in parts, when one part needs its own color. Wins over
  /// [subtitle].
  final List<TextSpan>? subtitleSpans;
  final Color? subtitleColor;
  final Color? titleColor;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 60),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: SacFontSize.titleMedium,
                      fontWeight: FontWeight.w600,
                      color: titleColor ?? c.text,
                    ),
                  ),
                  if (subtitleSpans != null && subtitleSpans!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(children: subtitleSpans),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: SacFontSize.bodyMedium,
                        height: 1.3,
                        color: subtitleColor ?? c.textSecondary,
                      ),
                    ),
                  ] else if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: SacFontSize.bodyMedium,
                        height: 1.3,
                        color: subtitleColor ?? c.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            if (onTap != null && showChevron) ...[
              const SizedBox(width: 4),
              ExcludeSemantics(
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowRight01,
                  size: 18,
                  color: c.textTertiary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
    final body = Opacity(
      opacity: enabled ? 1 : AppTheme.disabledOpacity,
      child: row,
    );
    if (onTap == null) return MergeSemantics(child: body);
    return MergeSemantics(
      child: Semantics(
        button: true,
        enabled: enabled,
        child: SacInkWell(
          onTap: enabled ? onTap : null,
          pressedScale: SacMotion.rowPressScale,
          child: body,
        ),
      ),
    );
  }
}

/// Square icon tile in the accent tone (or in red for a destructive row).
class FamilyRowIcon extends StatelessWidget {
  const FamilyRowIcon(this.icon, {super.key, this.destructive = false});

  final HugeIconData icon;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final accent = SacAccent.of(context);
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: destructive ? c.errorContainer : accent.light,
        borderRadius: BorderRadius.circular(AppTheme.radiusXS),
      ),
      child: HugeIcon(
        icon: icon,
        size: 19,
        color: destructive ? c.onErrorContainer : accent.color,
      ),
    );
  }
}

/// A minor in the list: avatar, name and the line that matters now (what is
/// missing for the consent, or the club).
class DependentRow extends StatelessWidget {
  const DependentRow({super.key, required this.dependent, required this.onTap});

  final DependentSummary dependent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    // Each part with its own color: only what needs attention is tinted.
    final parts = <TextSpan>[];
    if (dependent.frozen) {
      parts.add(TextSpan(
        text: '${'family.frozen'.tr()} · ${'family.frozen_short'.tr()}',
        style: TextStyle(color: c.onErrorContainer),
      ));
    } else {
      final age = dependent.age;
      if (age != null) {
        parts.add(TextSpan(
          text: 'family.card.age'.tr(namedArgs: {'age': '$age'}),
        ));
      }
      final g = dependent.guardianship;
      if (!g.isVerified) {
        parts.add(g.evidenceUploaded
            ? TextSpan(text: 'family.row.form_in_review'.tr())
            : TextSpan(
                text: 'family.row.form_missing'.tr(),
                style: TextStyle(color: c.onWarningContainer),
              ));
      }
      parts.add(TextSpan(text: dependentClubLabel(dependent.clubMembership)));
    }
    return FamilyRow(
      key: ValueKey('family-dependent-${dependent.userId}'),
      leading: DependentAvatar(
        name: dependent.firstName,
        imageUrl: dependent.userImage,
        size: 42,
      ),
      title: dependent.fullName,
      subtitleSpans: [
        for (var i = 0; i < parts.length; i++) ...[
          if (i > 0) const TextSpan(text: ' · '),
          parts[i],
        ],
      ],
      onTap: onTap,
    );
  }
}
