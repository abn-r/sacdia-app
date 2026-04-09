import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/features/honors/domain/utils/honor_category_colors.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/features/honors/domain/entities/user_honor.dart';
import 'package:sacdia_app/features/honors/presentation/providers/honors_providers.dart';

const Map<String, IconData> _categoryIcons = {
  'ADRA': Icons.volunteer_activism,
  'Actividades Agropecuarias': Icons.agriculture,
  'Ciencias de la Salud': Icons.medical_services,
  'Artes Domésticas': Icons.home,
  'Artes y Actividades Manuales': Icons.handyman,
  'Crecimiento Espiritual, Actividades Misioneras y Herencia': Icons.public,
  'Estudio de la Naturaleza': Icons.forest,
  'Actividades Vocacionales': Icons.work,
  'Actividades Recreativas': Icons.sports_handball,
};

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
    final userHonorsAsync = ref.watch(userHonorsProvider);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: userHonorsAsync.when(
      loading: () => _HonorsSkeleton(key: const ValueKey('honors-skeleton')),
      error: (e, _) => Padding(
        key: const ValueKey('honors-error'),
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            'Error al cargar especialidades',
            style: TextStyle(color: AppColors.error, fontSize: 14),
          ),
        ),
      ),
      data: (userHonors) {
        if (userHonors.isEmpty) {
          return Padding(
            key: const ValueKey('honors-data'),
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
            child: Column(
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedAward01,
                  size: 48,
                  color: context.sac.textTertiary,
                ),
                const SizedBox(height: 12),
                Text(
                  'Aún no tienes especialidades registradas',
                  style: TextStyle(
                    fontSize: 15,
                    color: context.sac.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                SacButton.outline(
                  text: 'Agregar especialidad',
                  icon: HugeIcons.strokeRoundedAdd01,
                  onPressed: () {
                    context.push(RouteNames.homeHonors);
                  },
                ),
              ],
            ),
          );
        }

        // Group userHonors by the category name embedded in the response.
        final Map<String, List<UserHonor>> byCategory = {};
        for (final uh in userHonors) {
          final key = uh.honorCategoryName ?? 'Sin categoría';
          byCategory.putIfAbsent(key, () => []).add(uh);
        }

        // Sort category names alphabetically A→Z.
        final sortedEntries = byCategory.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));

        return Column(
          key: const ValueKey('honors-data'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...sortedEntries.map((entry) {
              return _CategorySection(
                categoryName: entry.key,
                categoryId: entry.value.first.honorCategoryId,
                userHonors: entry.value,
              );
            }),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: SacButton.outline(
                text: 'Agregar especialidad',
                icon: HugeIcons.strokeRoundedAdd01,
                onPressed: () {
                  context.push(RouteNames.homeHonors);
                },
              ),
            ),
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
    final categoryIcon = _categoryIcons[categoryName] ?? Icons.star;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category header banner
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: categoryColor.withAlpha(80),
                  width: 1.5,
                ),
                bottom: BorderSide(
                  color: categoryColor.withAlpha(80),
                  width: 1.5,
                ),
              ),
              color: categoryColor.withAlpha(10),
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: categoryColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    categoryIcon,
                    color: Colors.white,
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
                      color: categoryColor,
                    ),
                  ),
                ),
                // Count badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: categoryColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: categoryColor.withAlpha(60),
                    ),
                  ),
                  child: Text(
                    '${userHonors.length}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: categoryColor,
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
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.78,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: userHonors.length,
            itemBuilder: (context, index) {
              return _HonorGridItem(
                userHonor: userHonors[index],
                categoryColor: categoryColor,
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

    final isCompleted = userHonor.validate;
    final imageUrl = userHonor.honorImageUrl;

    return GestureDetector(
      onTap: () => context.push(
        RouteNames.honorDetailPath(
          userHonor.honorId.toString(),
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: AspectRatio(
              aspectRatio: 1.0,
              child: Stack(
                children: [
                  imageUrl != null && imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.contain,
                          errorWidget: (_, __, ___) => _InitialsBox(
                            initials: initials,
                            categoryColor: categoryColor,
                          ),
                        )
                      : _InitialsBox(
                          initials: initials,
                          categoryColor: categoryColor,
                        ),
                  if (isCompleted)
                    Positioned(
                      top: 2,
                      right: 2,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: AppColors.secondary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 10,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 5),
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
            children: List.generate(3, (i) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: i == 0 ? 0 : 5, right: i == 2 ? 0 : 5),
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
            children: List.generate(3, (i) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: i == 0 ? 0 : 5, right: i == 2 ? 0 : 5),
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
