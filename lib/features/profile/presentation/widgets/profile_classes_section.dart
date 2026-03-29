import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/features/classes/domain/entities/progressive_class.dart';
import 'package:sacdia_app/features/classes/presentation/providers/classes_providers.dart';
import 'package:sacdia_app/features/classes/presentation/views/class_detail_with_progress_view.dart';
import 'package:sacdia_app/features/classes/presentation/views/classes_list_view.dart';

/// Section of the profile view that shows the user's enrolled progressive
/// classes in a 3-column grid, visually consistent with [ProfileHonorsSection].
class ProfileClassesSection extends ConsumerWidget {
  const ProfileClassesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classesAsync = ref.watch(userClassesProvider);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: classesAsync.when(
      loading: () => _ClassesSkeleton(key: const ValueKey('classes-skeleton')),
      error: (e, _) => Padding(
        key: const ValueKey('classes-error'),
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            'Error al cargar clases',
            style: TextStyle(color: AppColors.error, fontSize: 14),
          ),
        ),
      ),
      data: (classes) {
        if (classes.isEmpty) {
          return Padding(
            key: const ValueKey('classes-data'),
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
            child: Column(
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedSchool,
                  size: 48,
                  color: context.sac.textTertiary,
                ),
                const SizedBox(height: 12),
                Text(
                  'Aún no tienes clases registradas',
                  style: TextStyle(
                    fontSize: 15,
                    color: context.sac.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                SacButton.outline(
                  text: 'Ver clases disponibles',
                  icon: HugeIcons.strokeRoundedAdd01,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ClassesListView(),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        }

        return Column(
          key: const ValueKey('classes-data'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Class header banner
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: AppColors.primary.withAlpha(80),
                    width: 1.5,
                  ),
                  bottom: BorderSide(
                    color: AppColors.primary.withAlpha(80),
                    width: 1.5,
                  ),
                ),
                color: AppColors.primary.withAlpha(10),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.school,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Mis Clases',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  // Count badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(20),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.primary.withAlpha(60),
                      ),
                    ),
                    child: Text(
                      '${classes.length}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Classes grid (3 columns)
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
              itemCount: classes.length,
              itemBuilder: (context, index) {
                final progressiveClass = classes[index];
                return _ClassGridItem(
                  progressiveClass: progressiveClass,
                );
              },
            ),
          ],
        );
      },
    ),
    );
  }
}

class _ClassGridItem extends StatelessWidget {
  final ProgressiveClass progressiveClass;

  const _ClassGridItem({
    required this.progressiveClass,
  });

  @override
  Widget build(BuildContext context) {
    final classColor = AppColors.classColor(progressiveClass.name);
    final logoAsset = AppColors.classLogoAsset(progressiveClass.name);

    final progress = progressiveClass.overallProgress ?? 0;
    final isInvested = progressiveClass.investitureStatus == 'INVESTIDO';

    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ClassDetailWithProgressView(
                    classId: progressiveClass.id,
                  ),
                ),
              );
            },
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: classColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isInvested
                          ? classColor
                          : classColor.withAlpha(50),
                      width: isInvested ? 2 : 1,
                    ),
                  ),
                  padding: const EdgeInsets.all(10),
                  child: logoAsset != null
                      ? Image.asset(
                          logoAsset,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.school,
                            size: 30,
                            color: classColor,
                          ),
                        )
                      : Icon(
                          Icons.school,
                          size: 30,
                          color: classColor,
                        ),
                ),
                // Progress badge (top-right)
                if (progress > 0 && !isInvested)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: classColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$progress%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                // Invested badge (top-right checkmark)
                if (isInvested)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: classColor,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          progressiveClass.name,
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

// ── Skeleton placeholder for classes section ──────────────────────────────────

class _ClassesSkeleton extends StatelessWidget {
  const _ClassesSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final skeletonColor = context.sac.surfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Simulate the category header banner
          Container(
            height: 52,
            decoration: BoxDecoration(
              color: skeletonColor,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 10),
          // Simulate a row of 3 class cards
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

