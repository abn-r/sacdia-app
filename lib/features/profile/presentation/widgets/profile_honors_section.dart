import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/features/honors/presentation/theme/honor_category_palette.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/widgets/sac_network_image.dart';
import 'package:sacdia_app/features/honors/domain/entities/user_honor.dart';
import 'package:sacdia_app/features/honors/presentation/providers/honors_providers.dart';
import 'package:sacdia_app/features/master_honors/presentation/widgets/master_honor_history_section.dart';
import 'package:sacdia_app/features/honors/presentation/utils/user_honor_presentation_extensions.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import '../utils/profile_honor_navigation.dart';
import 'profile_quiet_add_chip.dart';

const Map<String, List<List<dynamic>>> _categoryIcons = {
  'ADRA': HugeIcons.strokeRoundedCharity,
  'Actividades Agropecuarias': HugeIcons.strokeRoundedPlant03,
  'Ciencias de la Salud': HugeIcons.strokeRoundedFirstAidKit,
  'Artes Domésticas': HugeIcons.strokeRoundedHome01,
  'Artes y Actividades Manuales': HugeIcons.strokeRoundedTools,
  'Crecimiento Espiritual, Actividades Misioneras y Herencia':
      HugeIcons.strokeRoundedGlobe02,
  'Estudio de la Naturaleza': HugeIcons.strokeRoundedTree01,
  'Actividades Vocacionales': HugeIcons.strokeRoundedBriefcase01,
  'Actividades Recreativas': HugeIcons.strokeRoundedFootball,
};

bool _isLightColor(Color color) => color.computeLuminance() > 0.78;

Color _paintColorForCategory(Color categoryColor, Color categoryAccentColor) {
  return _isLightColor(categoryColor) ? categoryAccentColor : categoryColor;
}

Color _foregroundColorForPaint(BuildContext context, Color color) {
  return _isLightColor(color) ? context.sac.text : Colors.white;
}

Color _categoryTextColor(BuildContext context, Color color) {
  return _isLightColor(color) ? context.sac.text : color;
}

final _profileHonorsByCategoryProvider =
    Provider.autoDispose<AsyncValue<List<_HonorCategoryGroup>>>((ref) {
  final userHonorsAsync = ref.watch(sectionScopedUserHonorsProvider);
  return userHonorsAsync.whenData(_groupUserHonorsByCategory);
});

List<_HonorCategoryGroup> _groupUserHonorsByCategory(
  List<UserHonor> userHonors,
) {
  final byCategory = <String, List<UserHonor>>{};
  final categoryIds = <String, int?>{};

  for (final userHonor in userHonors) {
    final key = userHonor.honorCategoryName?.trim().isNotEmpty == true
        ? userHonor.honorCategoryName!.trim()
        : '';
    byCategory.putIfAbsent(key, () => []).add(userHonor);
    categoryIds.putIfAbsent(key, () => userHonor.honorCategoryId);
  }

  final sortedKeys = byCategory.keys.toList()
    ..sort((a, b) {
      if (a.isEmpty) return 1;
      if (b.isEmpty) return -1;
      return a.compareTo(b);
    });

  return [
    for (final key in sortedKeys)
      _HonorCategoryGroup(
        categoryName: key.isEmpty ? null : key,
        categoryId: categoryIds[key],
        userHonors: byCategory[key]!,
      ),
  ];
}

class _HonorCategoryGroup {
  final String? categoryName;
  final int? categoryId;
  final List<UserHonor> userHonors;

  const _HonorCategoryGroup({
    required this.categoryName,
    required this.categoryId,
    required this.userHonors,
  });
}

/// Section of the profile view that shows the user's earned / in-progress
/// specialities grouped by category.
///
/// Groups directly by [UserHonor.honorCategoryName] which is embedded in the
/// GET /users/:userId/honors response — no separate catalog fetch required.
/// This avoids the pagination bug where only the first page of the full honors
/// catalog was cross-referenced, causing categories beyond the page limit to
/// disappear.
class ProfileHonorsSection extends ConsumerWidget {
  const ProfileHonorsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userHonorsAsync = ref.watch(_profileHonorsByCategoryProvider);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: userHonorsAsync.when(
        loading: () => _HonorsSkeleton(key: const ValueKey('honors-skeleton')),
        error: (e, _) => Padding(
          key: const ValueKey('honors-error'),
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Center(
            child: Text(
              'profile.honors_section.error_load'.tr(),
              style: TextStyle(color: AppColors.error, fontSize: 14),
            ),
          ),
        ),
        data: (groups) {
          if (groups.isEmpty) {
            return Column(
              key: const ValueKey('honors-data'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                  child: Column(
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedMedal02,
                        size: 48,
                        color: context.sac.textTertiary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'profile.honors_section.no_honors'.tr(),
                        style: TextStyle(
                          fontSize: 15,
                          color: context.sac.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ProfileQuietAddChip(
                        semanticLabel: 'profile.honors_section.add_honor'.tr(),
                        onTap: () {
                          context.push(RouteNames.homeHonors);
                        },
                      ),
                    ],
                  ),
                ),
                const MasterHonorHistorySection(),
              ],
            );
          }

          return Column(
            key: const ValueKey('honors-data'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...groups.map((group) {
                return _CategorySection(
                  categoryName: group.categoryName ??
                      'profile.honors_section.sin_categoria'.tr(),
                  categoryId: group.categoryId,
                  userHonors: group.userHonors,
                );
              }),
              const MasterHonorHistorySection(),
            ],
          );
        },
      ),
    );
  }
}

// ── Category section ──────────────────────────────────────────────────────────

class _CategorySection extends StatelessWidget {
  final String categoryName;
  final int? categoryId;
  final List<UserHonor> userHonors;

  const _CategorySection({
    required this.categoryName,
    this.categoryId,
    required this.userHonors,
  });

  @override
  Widget build(BuildContext context) {
    final categoryColor = getCategoryColor(
      categoryId: categoryId,
      categoryName: categoryName,
    );
    final categoryAccentColor = getCategoryAccentColor(
      categoryId: categoryId,
      categoryName: categoryName,
    );
    final categoryPaintColor =
        _paintColorForCategory(categoryColor, categoryAccentColor);
    final categoryForegroundColor =
        _foregroundColorForPaint(context, categoryPaintColor);
    final categoryTextColor = _categoryTextColor(context, categoryPaintColor);
    final categoryIcon =
        _categoryIcons[categoryName] ?? HugeIcons.strokeRoundedStar;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category header banner
          Container(
            // decoration: BoxDecoration(
            //   border: Border(
            //     top: BorderSide(
            //       color: categoryColor.withAlpha(80),
            //       width: 1.5,
            //     ),
            //     bottom: BorderSide(
            //       color: categoryColor.withAlpha(80),
            //       width: 1.5,
            //     ),
            //   ),
            //   color: categoryColor.withAlpha(10),
            // ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: categoryPaintColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: HugeIcon(
                    icon: categoryIcon,
                    color: categoryForegroundColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    categoryName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: categoryTextColor,
                    ),
                  ),
                ),
                // Count badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: categoryPaintColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: categoryPaintColor.withAlpha(60),
                    ),
                  ),
                  child: Text(
                    '${userHonors.length}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: categoryTextColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Honor grid (3 columns)
          GridView.builder(
            // shrinkWrap OK: honors per category are naturally bounded (each
            // category typically has < 30 items). Lives inside a Column that
            // is itself inside the profile's outer scroll view — intrinsic
            // height is required.
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.78,
              crossAxisSpacing: 10,
              mainAxisSpacing: 2.5,
            ),
            itemCount: userHonors.length,
            itemBuilder: (context, index) {
              return _HonorGridItem(
                userHonor: userHonors[index],
                categoryColor: categoryPaintColor,
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Honor grid item ───────────────────────────────────────────────────────────

class _HonorGridItem extends StatelessWidget {
  final UserHonor userHonor;
  final Color categoryColor;

  const _HonorGridItem({
    required this.userHonor,
    required this.categoryColor,
  });

  @override
  Widget build(BuildContext context) {
    final name = userHonor.honorName ?? '';
    final initials = name
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join('');

    final imageUrl = userHonor.honorImageUrl;

    return GestureDetector(
      onTap: () => context.push(profileHonorDestinationPath(userHonor)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 96,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                imageUrl != null && imageUrl.isNotEmpty
                    ? SacNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.contain,
                        memCacheWidth: 288,
                        memCacheHeight: 288,
                        errorWidget: (_, __, ___) => _InitialsBox(
                          initials: initials,
                          categoryColor: categoryColor,
                        ),
                      )
                    : _InitialsBox(
                        initials: initials,
                        categoryColor: categoryColor,
                      ),
                Positioned(
                  top: 2,
                  right: 2,
                  child: _HonorStatusBadge(
                    userHonor: userHonor,
                    categoryColor: categoryColor,
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
    );
  }
}

class _HonorStatusBadge extends StatelessWidget {
  final UserHonor userHonor;
  final Color categoryColor;

  const _HonorStatusBadge({
    required this.userHonor,
    required this.categoryColor,
  });

  @override
  Widget build(BuildContext context) {
    final meta = _HonorStatusBadgeMeta.fromUserHonor(
      context,
      userHonor: userHonor,
      categoryColor: categoryColor,
    );

    return Semantics(
      label: meta.semanticLabel,
      child: Tooltip(
        message: meta.semanticLabel,
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: meta.backgroundColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: meta.borderColor,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: HugeIcon(
            icon: meta.icon,
            color: meta.iconColor,
            size: 13,
          ),
        ),
      ),
    );
  }
}

class _HonorStatusBadgeMeta {
  final HugeIconData icon;
  final Color backgroundColor;
  final Color borderColor;
  final Color iconColor;
  final String semanticLabel;

  const _HonorStatusBadgeMeta({
    required this.icon,
    required this.backgroundColor,
    required this.borderColor,
    required this.iconColor,
    required this.semanticLabel,
  });

  factory _HonorStatusBadgeMeta.fromUserHonor(
    BuildContext context, {
    required UserHonor userHonor,
    required Color categoryColor,
  }) {
    final status = userHonor.displayStatus;
    final label = userHonor.statusLabel;

    switch (status) {
      case 'validado':
        return _HonorStatusBadgeMeta(
          icon: HugeIcons.strokeRoundedTick02,
          backgroundColor: AppColors.secondary,
          borderColor: Colors.white,
          iconColor: Colors.white,
          semanticLabel: label,
        );
      case 'enviado':
        return _HonorStatusBadgeMeta(
          icon: HugeIcons.strokeRoundedHourglass,
          backgroundColor: AppColors.info,
          borderColor: Colors.white,
          iconColor: Colors.white,
          semanticLabel: label,
        );
      case 'rechazado':
        return _HonorStatusBadgeMeta(
          icon: HugeIcons.strokeRoundedAlert02,
          backgroundColor: AppColors.error,
          borderColor: Colors.white,
          iconColor: Colors.white,
          semanticLabel: label,
        );
      case 'en_progreso':
        return _HonorStatusBadgeMeta(
          icon: HugeIcons.strokeRoundedEdit02,
          backgroundColor: categoryColor,
          borderColor: Colors.white,
          iconColor: _foregroundColorForPaint(context, categoryColor),
          semanticLabel: label,
        );
      case 'inscrito':
      default:
        return _HonorStatusBadgeMeta(
          icon: HugeIcons.strokeRoundedCircle,
          backgroundColor: context.sac.surface,
          borderColor: AppColors.pendingColor.withValues(alpha: 0.65),
          iconColor: AppColors.pendingColor,
          semanticLabel: label,
        );
    }
  }
}

// ── Initials fallback ─────────────────────────────────────────────────────────

class _InitialsBox extends StatelessWidget {
  final String initials;
  final Color categoryColor;

  const _InitialsBox({
    required this.initials,
    required this.categoryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: categoryColor.withAlpha(20),
        shape: BoxShape.circle,
        border: Border.all(color: categoryColor.withAlpha(60), width: 1.5),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: categoryColor,
          ),
        ),
      ),
    );
  }
}

// ── Skeleton placeholder for honors section ───────────────────────────────────

class _HonorsSkeleton extends StatelessWidget {
  const _HonorsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final skeletonColor = context.sac.surfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Simulate first category header
          Container(
            height: 52,
            decoration: BoxDecoration(
              color: skeletonColor,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 10),
          // Simulate a row of 3 honor cards
          Row(
            children: List.generate(
                3,
                (i) => Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                            left: i == 0 ? 0 : 5, right: i == 2 ? 0 : 5),
                        child: Container(
                          height: 90,
                          decoration: BoxDecoration(
                            color: skeletonColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    )),
          ),
          const SizedBox(height: 20),
          // Simulate a second category header
          Container(
            height: 52,
            decoration: BoxDecoration(
              color: skeletonColor,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 10),
          // Simulate a second row of cards
          Row(
            children: List.generate(
                3,
                (i) => Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                            left: i == 0 ? 0 : 5, right: i == 2 ? 0 : 5),
                        child: Container(
                          height: 90,
                          decoration: BoxDecoration(
                            color: skeletonColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    )),
          ),
        ],
      ),
    );
  }
}
