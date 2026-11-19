import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/animations/page_transitions.dart';
import 'package:sacdia_app/core/animations/staggered_list_animation.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:sacdia_app/core/widgets/status_progress/sac_grouped_section.dart';
import 'package:sacdia_app/features/dashboard/presentation/widgets/class_logo_box.dart';

import '../../domain/entities/progressive_class.dart';
import '../catalog/class_catalog.dart';
import '../views/class_catalog_view.dart';
import '../views/class_detail_with_progress_view.dart';

/// Club types relevant to the user: those where the user has at least one
/// class (invested, in progress or expired). A club the user never took a
/// class in (e.g. Aventureros for a Master Guide) stays out; the full list
/// lives in «Clases por club».
List<ClassCatalogSection> relevantClubSections(
  List<ClassCatalogSection> sections,
) =>
    [
      for (final section in sections)
        if (section.entries.any(
          (e) => e.status != ClassCatalogStatus.notInvested,
        ))
          section,
    ];

/// The enrollment a catalog row opens: the invested one, else the newest.
ProgressiveClass? enrollmentForClass(
  List<ProgressiveClass> enrolled,
  int classId,
) {
  ProgressiveClass? newest;
  for (final e in enrolled) {
    if (e.id != classId) continue;
    if (e.isInvested) return e;
    newest ??= e;
  }
  return newest;
}

/// One grouped section per club type: «CONQUISTADORES · 10 a 15 años» and the
/// club's classes with the user's standing.
class ClassClubLists extends StatelessWidget {
  const ClassClubLists({
    super.key,
    required this.sections,
    required this.enrolled,
    this.firstIndex = 1,
  });

  /// Entrance position of the first group; the next ones follow.
  final int firstIndex;
  final List<ClassCatalogSection> sections;
  final List<ProgressiveClass> enrolled;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final (i, section) in relevantClubSections(sections).indexed)
          SacEntrance(
            index: firstIndex + i,
            child: SacGroupedSection(
              label: 'classes.catalog.club_${section.clubTypeId}'.tr(),
              dividerIndent: 62,
              action: _ages(context, section),
              children: [
                for (final entry in section.entries)
                  _ClubClassRow(
                    entry: entry,
                    enrollment: enrollmentForClass(enrolled, entry.classId),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _ages(BuildContext context, ClassCatalogSection section) {
    final min = section.minAge;
    final max = section.maxAge;
    final text = min == null
        ? null
        : max == null
            ? 'classes.list.ages_open'.tr(namedArgs: {'min': '$min'})
            : formatClassAges(min, max);
    return Text(
      text ?? '',
      style: TextStyle(
        fontSize: SacFontSize.labelSmall,
        fontWeight: FontWeight.w600,
        color: context.sac.textTertiary,
      ),
    );
  }
}

class _ClubClassRow extends StatelessWidget {
  const _ClubClassRow({required this.entry, required this.enrollment});

  final ClassCatalogEntry entry;

  /// Null when the user never enrolled: nothing to open.
  final ProgressiveClass? enrollment;

  void _open(BuildContext context) {
    final e = enrollment;
    if (e == null) return;
    Navigator.push(
      context,
      SacSharedAxisRoute(
        builder: (_) => ClassDetailWithProgressView(
          classId: e.id,
          enrollmentId: e.enrollmentId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final ages = formatClassAges(entry.minAge, entry.maxAge);
    final isOpenable = enrollment != null;

    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        child: Row(
          children: [
            ClassLogoBox(
              className: entry.name,
              imageUrl: entry.imageUrl,
              size: 36,
              radius: AppTheme.radiusSM,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    entry.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: SacFontSize.titleMedium,
                      fontWeight: FontWeight.w600,
                      color: c.text,
                    ),
                  ),
                  if (ages != null)
                    Text(
                      ages,
                      style: TextStyle(
                        fontSize: SacFontSize.bodySmall,
                        color: c.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ClassCatalogStatusBadge(entry: entry),
            if (isOpenable) ...[
              const SizedBox(width: 6),
              HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                size: 18,
                color: c.textTertiary,
              ),
            ],
          ],
        ),
      ),
    );

    return Semantics(
      container: true,
      button: isOpenable,
      excludeSemantics: true,
      label: [
        entry.name,
        if (ages != null) ages,
        classCatalogStatusLabel(entry),
      ].join('. '),
      onTap: isOpenable ? () => _open(context) : null,
      child: isOpenable
          ? SacInkWell(
              onTap: () => _open(context),
              pressedScale: SacMotion.rowPressScale,
              child: content,
            )
          : content,
    );
  }
}
