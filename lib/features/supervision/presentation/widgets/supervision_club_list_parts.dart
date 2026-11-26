import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_list_row.dart';
import 'package:sacdia_app/core/widgets/sac_tone.dart';
import 'package:sacdia_app/core/widgets/status_progress/sac_grouped_section.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_club.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_identity_tiles.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_status_chip.dart';

/// Clubs of the loaded pages grouped by local field.
///
/// The server does not sort by field, so the loaded clubs are sorted here by
/// field and then by name (stable). With more pages to come the groups can
/// still grow, so the callers hide the group count until everything loaded.
class SupervisionClubGroup {
  const SupervisionClubGroup(
      {required this.localFieldName, required this.clubs});

  final String localFieldName;
  final List<SupervisionClubListItem> clubs;
}

List<SupervisionClubGroup> groupSupervisionClubsByField(
  List<SupervisionClubListItem> items,
) {
  String key(SupervisionClubListItem club) =>
      club.localFieldName.trim().toLowerCase();
  // Dart's sort is not stable: the index keeps the server order on ties.
  final indexed = items.indexed.toList()
    ..sort((a, b) {
      final byField = key(a.$2).compareTo(key(b.$2));
      if (byField != 0) return byField;
      final byName = a.$2.name.toLowerCase().compareTo(b.$2.name.toLowerCase());
      return byName != 0 ? byName : a.$1.compareTo(b.$1);
    });
  final groups = <SupervisionClubGroup>[];
  for (final (_, club) in indexed) {
    if (groups.isNotEmpty && key(groups.last.clubs.first) == key(club)) {
      groups.last.clubs.add(club);
    } else {
      groups.add(
        SupervisionClubGroup(
          localFieldName: club.localFieldName.trim(),
          clubs: [club],
        ),
      );
    }
  }
  return groups;
}

/// One local field and its clubs. [label] is the field name (or the generic
/// «Clubes» when the club carries none).
class SupervisionClubGroupSection extends StatelessWidget {
  const SupervisionClubGroupSection({
    super.key,
    required this.group,
    required this.showCount,
    required this.onOpen,
  });

  final SupervisionClubGroup group;

  /// False while more pages are coming: the count would still change.
  final bool showCount;
  final ValueChanged<SupervisionClubListItem> onOpen;

  @override
  Widget build(BuildContext context) {
    return SacGroupedSection(
      label: group.localFieldName.isEmpty
          ? 'supervision.clubs.title'.tr()
          : group.localFieldName,
      dividerIndent: 16,
      count: group.clubs.length,
      action: showCount ? null : const SizedBox.shrink(),
      children: [
        for (final club in group.clubs)
          SupervisionClubRow(club: club, onTap: () => onOpen(club)),
      ],
    );
  }
}

/// Monogram, name, «Iglesia · Distrito» and the logos of the active sections.
/// An inactive club is dimmed and says so with a muted chip.
class SupervisionClubRow extends StatelessWidget {
  const SupervisionClubRow(
      {super.key, required this.club, required this.onTap});

  final SupervisionClubListItem club;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final place = [club.churchName, club.districtName]
        .where((part) => part.trim().isNotEmpty)
        .join(' · ');
    final sections = club.activeSectionNames;
    final inactive = !club.active;
    return SacListRow(
      leading: SupervisionMonogram(name: club.name, dimmed: inactive),
      title: club.name,
      titleColor: inactive ? c.textTertiary : null,
      subtitleColor: inactive ? c.textTertiary : null,
      subtitle: [
        if (place.isNotEmpty) place,
        if (club.active && sections.isEmpty)
          'supervision.clubs.no_sections'.tr(),
      ].join('\n'),
      trailing: inactive
          // Capped so a large text scale wraps the chip, not the row.
          ? ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.32,
              ),
              child: SupervisionStatusChip(
                label: 'supervision.clubs.inactive'.tr(),
                icon: HugeIcons.strokeRoundedPauseCircle,
                tone: SacTone.muted,
              ),
            )
          : sections.isEmpty
              ? null
              : SupervisionSectionLogos(typeNames: sections),
      onTap: onTap,
    );
  }
}

/// Small logos of the club types a club runs, overlapped slightly.
class SupervisionSectionLogos extends StatelessWidget {
  const SupervisionSectionLogos({super.key, required this.typeNames});

  final List<String> typeNames;

  static const double _size = 24;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < typeNames.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          SupervisionClubTypeLogo(typeName: typeNames[i], size: _size),
        ],
      ],
    );
  }
}
