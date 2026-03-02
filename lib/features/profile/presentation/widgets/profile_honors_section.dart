import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/features/honors/presentation/views/add_honor_view.dart';
import 'package:sacdia_app/features/honors/domain/entities/honor.dart';
import 'package:sacdia_app/features/honors/domain/entities/honor_category.dart';
import 'package:sacdia_app/features/honors/domain/entities/user_honor.dart';
import 'package:sacdia_app/features/honors/domain/usecases/get_honors.dart';
import 'package:sacdia_app/features/honors/presentation/providers/honors_providers.dart';

/// Category color and icon map – mirrors the reference implementation but uses
/// AppColors constants already defined in the design system.
const Map<String, Color> _categoryColors = {
  'ADRA': AppColors.catAdra,
  'Agropecuarias': AppColors.catagropecuarias,
  'Ciencias de la Salud': AppColors.catCienciasSalud,
  'Domésticas': AppColors.catDomesticas,
  'Habilidades Manuales': AppColors.catHabilidadesManuales,
  'Misioneras': AppColors.catMisioneras,
  'Naturaleza': AppColors.catNaturaleza,
  'Profesionales': AppColors.catProfesionales,
  'Recreativas': AppColors.catRecreativas,
};

const Map<String, IconData> _categoryIcons = {
  'ADRA': Icons.volunteer_activism,
  'Agropecuarias': Icons.agriculture,
  'Ciencias de la Salud': Icons.medical_services,
  'Domésticas': Icons.home,
  'Habilidades Manuales': Icons.handyman,
  'Misioneras': Icons.public,
  'Naturaleza': Icons.forest,
  'Profesionales': Icons.work,
  'Recreativas': Icons.sports_handball,
};

/// Section of the profile view that shows the user's earned / in-progress
/// specialities grouped by category in a 3-column grid.
///
/// Adapts the reference `_buildCategorySection` / `_buildHonorItem` logic to
/// the Riverpod architecture used in the current app.
class ProfileHonorsSection extends ConsumerWidget {
  const ProfileHonorsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userHonorsAsync = ref.watch(userHonorsProvider);
    final categoriesAsync = ref.watch(honorCategoriesProvider);
    final allHonorsAsync = ref.watch(honorsProvider(const GetHonorsParams()));

    return userHonorsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: SacLoading()),
      ),
      error: (e, _) => Padding(
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
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AddHonorView(),
                      ),
                    ).then((result) {
                      if (result == true) {
                        ref.invalidate(userHonorsProvider);
                      }
                    });
                  },
                ),
              ],
            ),
          );
        }

        return categoriesAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: SacLoading()),
          ),
          error: (_, __) => const SizedBox.shrink(),
          data: (categories) => allHonorsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: SacLoading()),
            ),
            error: (_, __) => const SizedBox.shrink(),
            data: (allHonors) {
              // Build enriched data: category → list of (honor, userHonor)
              final userHonorMap = {for (final uh in userHonors) uh.honorId: uh};
              final earnedHonorIds = userHonorMap.keys.toSet();

              // Filter honors that belong to the user
              final earnedHonors =
                  allHonors.where((h) => earnedHonorIds.contains(h.id)).toList();

              // Group by categoryId
              final Map<int, List<Honor>> byCategory = {};
              for (final h in earnedHonors) {
                byCategory.putIfAbsent(h.categoryId, () => []).add(h);
              }

              // Build ordered list matching categories
              final relevantCategories = categories
                  .where((cat) => byCategory.containsKey(cat.id))
                  .toList();

              if (relevantCategories.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      'No hay especialidades disponibles',
                      style: TextStyle(color: context.sac.textSecondary),
                    ),
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...relevantCategories.map((category) {
                    final honors = byCategory[category.id] ?? [];
                    return _CategorySection(
                      category: category,
                      honors: honors,
                      userHonorMap: userHonorMap,
                    );
                  }),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    child: SacButton.outline(
                      text: 'Agregar especialidad',
                      icon: HugeIcons.strokeRoundedAdd01,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AddHonorView(),
                          ),
                        ).then((result) {
                          if (result == true) {
                            ref.invalidate(userHonorsProvider);
                          }
                        });
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _CategorySection extends StatelessWidget {
  final HonorCategory category;
  final List<Honor> honors;
  final Map<int, UserHonor> userHonorMap;

  const _CategorySection({
    required this.category,
    required this.honors,
    required this.userHonorMap,
  });

  @override
  Widget build(BuildContext context) {
    final categoryColor =
        _categoryColors[category.name] ?? AppColors.sacBlack;
    final categoryIcon = _categoryIcons[category.name] ?? Icons.star;

    // Naturaleza has a white colour swatch – use dark text for contrast
    final isNature = category.name == 'Naturaleza' ||
        category.name == 'Estudio de la naturaleza';

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
                  color: isNature
                      ? AppColors.sacBlack.withAlpha(80)
                      : categoryColor.withAlpha(80),
                  width: 1.5,
                ),
                bottom: BorderSide(
                  color: isNature
                      ? AppColors.sacBlack.withAlpha(80)
                      : categoryColor.withAlpha(80),
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
                    color: isNature ? AppColors.sacBlack : Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    category.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color:
                          isNature ? AppColors.sacBlack : categoryColor,
                    ),
                  ),
                ),
                // Count badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: categoryColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isNature
                          ? AppColors.sacBlack.withAlpha(60)
                          : categoryColor.withAlpha(60),
                    ),
                  ),
                  child: Text(
                    '${honors.length}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isNature
                          ? AppColors.sacBlack
                          : categoryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Honor grid (3 columns)
          GridView.builder(
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
            itemCount: honors.length,
            itemBuilder: (context, index) {
              final honor = honors[index];
              final userHonor = userHonorMap[honor.id];
              return _HonorGridItem(
                honor: honor,
                userHonor: userHonor,
                categoryColor: categoryColor,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HonorGridItem extends StatelessWidget {
  final Honor honor;
  final UserHonor? userHonor;
  final Color categoryColor;

  const _HonorGridItem({
    required this.honor,
    required this.userHonor,
    required this.categoryColor,
  });

  @override
  Widget build(BuildContext context) {
    final initials = honor.name
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join('');

    final isCompleted = userHonor?.status.toLowerCase() == 'completed';

    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              // TODO: navigate to honor detail when that view exists in the
              // new architecture.
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(honor.name),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: honor.imageUrl != null && honor.imageUrl!.isNotEmpty
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          honor.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _InitialsBox(
                            initials: initials,
                            categoryColor: categoryColor,
                          ),
                        ),
                        if (isCompleted)
                          Positioned(
                            top: 4,
                            right: 4,
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
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        _InitialsBox(
                          initials: initials,
                          categoryColor: categoryColor,
                        ),
                        if (isCompleted)
                          Positioned(
                            top: 4,
                            right: 4,
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
        ),
        const SizedBox(height: 4),
        Text(
          honor.name,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: context.sac.text,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

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
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: categoryColor.withAlpha(50), width: 1),
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
