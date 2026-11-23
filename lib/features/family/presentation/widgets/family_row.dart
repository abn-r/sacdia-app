import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_list_row.dart';
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
    return SacListRow(
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

/// One line under a group: why its rows are off, or what they are for.
class FamilyFootnote extends StatelessWidget {
  const FamilyFootnote({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      child: Text(
        text,
        style: TextStyle(
          fontSize: SacFontSize.bodyMedium,
          height: 1.4,
          color: context.sac.textSecondary,
        ),
      ),
    );
  }
}
