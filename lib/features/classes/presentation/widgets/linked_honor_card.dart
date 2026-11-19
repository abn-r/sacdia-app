import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_tweened_bar.dart';
import '../../../honors/presentation/providers/honors_providers.dart';

/// The honor a requirement is linked to, in place of the file grid: its image,
/// its name and, when the member is doing it, how many of its requirements are
/// done. The requirement validates itself when the honor is completed.
///
/// Image and progress come from the member's own honors, so they are only
/// looked up when [isOwn] is true; a coach looking at a member sees the name
/// and the status.
class LinkedHonorCard extends ConsumerWidget {
  const LinkedHonorCard({
    super.key,
    required this.honorId,
    required this.honorName,
    required this.isCompleted,
    this.isOwn = true,
  });

  final int honorId;
  final String? honorName;
  final bool isCompleted;
  final bool isOwn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final accent = SacAccent.of(context);

    String? imageUrl;
    int? done;
    int? total;
    if (isOwn) {
      final userHonors = ref.watch(userHonorsProvider).value;
      for (final userHonor in userHonors ?? const []) {
        if (userHonor.honorId == honorId) {
          imageUrl = userHonor.honorImageUrl;
          break;
        }
      }
      final progress = ref.watch(userHonorProgressProvider(honorId)).value;
      if (progress != null && progress.isNotEmpty) {
        total = progress.length;
        done = progress.where((p) => p.completed).length;
      }
    }

    final name = (honorName ?? '').trim();
    final detail = done != null && total != null
        ? 'classes.requirement_detail.honor_progress'
            .tr(namedArgs: {'done': '$done', 'total': '$total'})
        : (isCompleted
            ? 'classes.requirement_detail.honor_completed'.tr()
            : 'classes.requirement_detail.honor_pending'.tr());

    final image = Container(
      width: 56,
      height: 56,
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: accent.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
      ),
      child: imageUrl != null && imageUrl.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: imageUrl,
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              memCacheWidth: 168,
              errorWidget: (_, __, ___) => HugeIcon(
                icon: HugeIcons.strokeRoundedAward01,
                size: 26,
                color: accent.color,
              ),
            )
          : HugeIcon(
              icon: HugeIcons.strokeRoundedAward01,
              size: 26,
              color: accent.color,
            ),
    );

    return Semantics(
      container: true,
      label: [if (name.isNotEmpty) name, detail].join('. '),
      excludeSemantics: true,
      child: Container(
        key: const ValueKey('linked-honor-card'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          border: Border.all(color: c.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                image,
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (name.isNotEmpty)
                        Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: SacFontSize.titleLarge,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                            color: c.text,
                          ),
                        ),
                      Text(
                        detail,
                        key: const ValueKey('linked-honor-detail'),
                        style: TextStyle(
                          fontSize: SacFontSize.bodyMedium,
                          color: c.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (done != null && total != null && total > 0) ...[
              const SizedBox(height: 12),
              SacTweenedBar(
                value: done / total,
                minHeight: 4,
                backgroundColor: c.surfaceVariant,
                color: isCompleted ? c.success : accent.color,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
