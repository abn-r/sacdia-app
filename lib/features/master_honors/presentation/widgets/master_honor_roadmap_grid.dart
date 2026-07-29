import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_network_image.dart';
import 'package:sacdia_app/features/master_honors/domain/entities/master_honor_roadmap.dart';

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
    return GridView.builder(
      shrinkWrap: shrinkWrap,
      physics: physics,
      padding: padding,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.78,
        crossAxisSpacing: 10,
        mainAxisSpacing: 2.5,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        return MasterHonorRoadmapGridItem(item: items[index]);
      },
    );
  }
}

class MasterHonorRoadmapGridItem extends StatelessWidget {
  const MasterHonorRoadmapGridItem({super.key, required this.item});

  final MasterHonorRoadmap item;

  @override
  Widget build(BuildContext context) {
    final accent = masterHonorAccentColor(item);
    final isLocked = !item.isAwarded;
    final visualColor = isLocked ? context.sac.textTertiary : accent;
    final name = item.name;

    final statusLabel = item.isAwarded
        ? (item.displayStatusLabel ?? 'Maestría obtenida')
        : 'Maestría en progreso';

    return Semantics(
      button: true,
      label: '$name, $statusLabel, ${item.progressPercent}% completado',
      child: GestureDetector(
        onTap: () => showMasterHonorDetailSheet(context, item),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 96,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Center(
                    child: _MutedMasterHonorLogo(
                      muted: isLocked,
                      child: MasterHonorLogo(
                        imageUrl: item.masterImage,
                        name: name,
                        size: 88,
                        color: visualColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              name,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: context.sac.text,
                height: 1.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _MutedMasterHonorLogo extends StatelessWidget {
  const _MutedMasterHonorLogo({
    required this.muted,
    required this.child,
  });

  final bool muted;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!muted) return child;

    return ColorFiltered(
      colorFilter: _grayscaleFilter,
      child: Opacity(
        opacity: 0.58,
        child: child,
      ),
    );
  }
}

class MasterHonorLogo extends StatelessWidget {
  const MasterHonorLogo({
    super.key,
    required this.imageUrl,
    required this.name,
    required this.size,
    required this.color,
  });

  final String? imageUrl;
  final String name;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final image = imageUrl?.trim() ?? '';
    final width = size * 1.25;
    final fallback = SizedBox(
      width: width,
      height: size,
      child: MasterHonorInitialsBox(
        initials: masterHonorInitials(name),
        color: color,
      ),
    );

    if (image.isEmpty) return fallback;

    return SizedBox(
      width: width,
      height: size,
      child: SacNetworkImage(
        imageUrl: image,
        fit: BoxFit.contain,
        memCacheWidth: (width * 3).round(),
        memCacheHeight: (size * 3).round(),
        placeholder: (_, __) => fallback,
        errorWidget: (_, __, ___) => fallback,
      ),
    );
  }
}

class MasterHonorInitialsBox extends StatelessWidget {
  const MasterHonorInitialsBox({
    super.key,
    required this.initials,
    required this.color,
  });

  final String initials;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha(60), width: 1.5),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ),
    );
  }
}

const ColorFilter _grayscaleFilter = ColorFilter.matrix(<double>[
  0.2126,
  0.7152,
  0.0722,
  0,
  0,
  0.2126,
  0.7152,
  0.0722,
  0,
  0,
  0.2126,
  0.7152,
  0.0722,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
]);

Future<void> showMasterHonorDetailSheet(
  BuildContext context,
  MasterHonorRoadmap item,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _MasterHonorDetailSheet(item: item),
  );
}

Color masterHonorAccentColor(MasterHonorRoadmap item) {
  return item.isAwarded ? AppColors.secondary : AppColors.warning;
}

class _MasterHonorDetailSheet extends StatelessWidget {
  const _MasterHonorDetailSheet({required this.item});

  final MasterHonorRoadmap item;

  @override
  Widget build(BuildContext context) {
    final accent = masterHonorAccentColor(item);
    final progress = item.progressPercent.clamp(0, 100).toDouble() / 100;
    final detailLogoHeight =
        (MediaQuery.sizeOf(context).width * 0.52).clamp(150.0, 230.0);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: context.sac.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: context.sac.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: MasterHonorLogo(
                    imageUrl: item.masterImage,
                    name: item.name,
                    size: detailLogoHeight,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  item.name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: context.sac.text,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: _StatusPill(
                    label: item.isAwarded
                        ? (item.displayStatusLabel ?? 'Obtenida')
                        : 'En progreso',
                    color: accent,
                  ),
                ),
                const SizedBox(height: 18),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: context.sac.surfaceVariant,
                    valueColor: AlwaysStoppedAnimation<Color>(accent),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${item.completedGroups}/${item.totalGroups} requisitos completados · ${item.progressPercent.clamp(0, 100)}%',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.sac.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  'Requisitos',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: context.sac.text,
                  ),
                ),
                const SizedBox(height: 10),
                if (item.requirementGroups.isEmpty)
                  Text(
                    'Aún no hay requisitos configurados para esta maestría.',
                    style: TextStyle(
                      fontSize: 13,
                      color: context.sac.textTertiary,
                    ),
                  )
                else
                  ...item.requirementGroups.map(
                    (group) => _RequirementDetailCard(group: group),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RequirementDetailCard extends StatelessWidget {
  const _RequirementDetailCard({required this.group});

  final MasterHonorRoadmapGroup group;

  @override
  Widget build(BuildContext context) {
    final accent = group.passed ? AppColors.secondary : AppColors.warning;
    final label = _requirementLabel(group);
    final detail = group.isCategoryCount
        ? '${group.currentCount}/${group.minimumRequired} especialidades'
        : '${group.currentCount}/${group.minimumRequired} opciones';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.sac.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.sac.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HugeIcon(
                icon: group.passed
                    ? HugeIcons.strokeRoundedCheckmarkCircle02
                    : HugeIcons.strokeRoundedCircle,
                size: 18,
                color: accent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: context.sac.text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      detail,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.sac.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (group.description?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text(
              group.description!.trim(),
              style: TextStyle(
                fontSize: 12,
                color: context.sac.textSecondary,
                height: 1.35,
              ),
            ),
          ],
          if (group.options.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...group.options.map(
              (option) => Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HugeIcon(
                      icon: option.completed
                          ? HugeIcons.strokeRoundedTick02
                          : HugeIcons.strokeRoundedCircle,
                      size: 14,
                      color: option.completed
                          ? AppColors.secondary
                          : context.sac.textTertiary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        option.label,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.sac.textSecondary,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
          height: 1,
        ),
      ),
    );
  }
}

String _requirementLabel(MasterHonorRoadmapGroup group) {
  final candidates = [
    group.title,
    group.categoryName,
    group.description,
  ];

  for (final candidate in candidates) {
    final value = candidate?.trim();
    if (value != null && value.isNotEmpty) return value;
  }

  return 'Requisito de maestría';
}

String masterHonorInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return 'M';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
}
