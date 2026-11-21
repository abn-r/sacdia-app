import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/widgets/badge_grid/sac_badge_card.dart';
import 'package:sacdia_app/core/widgets/badge_grid/sac_badge_grid.dart';
import 'package:sacdia_app/features/master_honors/domain/entities/master_honor_roadmap.dart';
import 'package:sacdia_app/features/master_honors/presentation/widgets/master_honor_detail_presentation.dart';
import 'package:sacdia_app/features/master_honors/presentation/widgets/master_honor_detail_sheet.dart';
import 'package:sacdia_app/features/master_honors/presentation/widgets/master_honor_logo.dart';

export 'master_honor_detail_presentation.dart'
    show MasterHonorGridVisual, masterHonorGridVisual, masterHonorShortName;
export 'master_honor_detail_sheet.dart' show showMasterHonorDetailSheet;
export 'master_honor_logo.dart';

/// Height of the patch slot: the oval fills the card width up to this height.
const double _kPatchHeight = 72;

/// Three-column grid of masteries, in the same card language as the
/// achievements grid (see [SacBadgeGrid]).
class MasterHonorRoadmapGrid extends StatelessWidget {
  const MasterHonorRoadmapGrid({
    super.key,
    required this.items,
    this.padding = const EdgeInsets.all(16),
    this.physics,
    this.shrinkWrap = false,
  });

  final List<MasterHonorRoadmap> items;
  final EdgeInsetsGeometry padding;
  final ScrollPhysics? physics;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    return SacBadgeGrid(
      padding: padding,
      physics: physics,
      shrinkWrap: shrinkWrap,
      artHeight: _kPatchHeight,
      itemCount: items.length,
      keyOf: (index) => ValueKey(items[index].masterHonorId),
      itemBuilder: (context, index) =>
          MasterHonorRoadmapGridItem(item: items[index]),
    );
  }
}

/// One mastery card:
///
/// - obtained: colour patch and "Obtenida";
/// - in progress: dimmed patch, a bar in the app accent and "3 de 7";
/// - no longer valid: colour patch and "No vigente" in the warning colour;
/// - no progress: grey patch, no meta.
///
/// The patch keeps its oval; the name drops the "Maestría en" prefix (the
/// screen title says it).
class MasterHonorRoadmapGridItem extends StatelessWidget {
  const MasterHonorRoadmapGridItem({super.key, required this.item});

  final MasterHonorRoadmap item;

  @override
  Widget build(BuildContext context) {
    final visual = masterHonorGridVisual(item);
    final accent = SacAccent.of(context).color;

    return SacBadgeCard(
      name: masterHonorShortName(item.name),
      artHeight: _kPatchHeight,
      tone: masterHonorTone(visual),
      nameEmphasized: visual == MasterHonorGridVisual.awarded ||
          visual == MasterHonorGridVisual.inactive,
      meta: _metaFor(visual),
      onTap: () => showMasterHonorDetailSheet(context, item),
      art: LayoutBuilder(
        builder: (context, constraints) => MasterHonorLogo(
          imageUrl: item.masterImage,
          name: masterHonorShortName(item.name),
          size: _kPatchHeight,
          width: constraints.maxWidth.isFinite ? constraints.maxWidth : null,
          color: accent,
        ),
      ),
    );
  }

  SacBadgeMeta _metaFor(MasterHonorGridVisual visual) {
    switch (visual) {
      case MasterHonorGridVisual.awarded:
        return SacBadgeMeta.obtained('master_honors.card.obtained'.tr());
      case MasterHonorGridVisual.inactive:
        return SacBadgeMeta.warning('master_honors.card.lapsed'.tr());
      case MasterHonorGridVisual.inProgress:
        final count = masterHonorProgressCount(item);
        if (count.total <= 0) return const SacBadgeMeta.none();
        return SacBadgeMeta.progress(
          fraction: count.current / count.total,
          label: 'master_honors.card.progress_fraction'.tr(
            namedArgs: {
              'current': '${count.current}',
              'total': '${count.total}',
            },
          ),
        );
      case MasterHonorGridVisual.locked:
        return const SacBadgeMeta.none();
    }
  }
}
