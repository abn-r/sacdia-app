import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/features/classes/domain/entities/progressive_class.dart';
import 'package:sacdia_app/features/classes/presentation/providers/classes_providers.dart';
import 'package:sacdia_app/features/classes/presentation/views/class_detail_view.dart';
import 'package:sacdia_app/features/classes/presentation/views/classes_list_view.dart';

/// Map class names to their brand colours (same palette as ClassStatusCircles).
const Map<String, Color> _classColors = {
  'Amigo': AppColors.colorAmigo,
  'Compañero': AppColors.colorCompanero,
  'Explorador': AppColors.colorExplorador,
  'Orientador': AppColors.colorOrientador,
  'Viajero': AppColors.colorViajero,
  'Guía': AppColors.colorGuia,
};

const Map<String, IconData> _classIcons = {
  'Amigo': Icons.handshake,
  'Compañero': Icons.people,
  'Explorador': Icons.explore,
  'Orientador': Icons.compass_calibration,
  'Viajero': Icons.flight_takeoff,
  'Guía': Icons.shield,
};

/// Section of the profile view that shows the user's enrolled progressive
/// classes in a 3-column grid, visually consistent with [ProfileHonorsSection].
class ProfileClassesSection extends ConsumerWidget {
  const ProfileClassesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classesAsync = ref.watch(userClassesProvider);

    return classesAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: SacLoading()),
      ),
      error: (e, _) => Padding(
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
    final classColor =
        _classColors[progressiveClass.name] ?? AppColors.primary;
    final classIcon =
        _classIcons[progressiveClass.name] ?? Icons.school;

    final initials = progressiveClass.name
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join('');

    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ClassDetailView(
                    classId: progressiveClass.id,
                  ),
                ),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: progressiveClass.imageUrl != null &&
                      progressiveClass.imageUrl!.isNotEmpty
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl: progressiveClass.imageUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _ClassInitialsBox(
                            initials: initials,
                            classColor: classColor,
                            classIcon: classIcon,
                          ),
                        ),
                      ],
                    )
                  : _ClassInitialsBox(
                      initials: initials,
                      classColor: classColor,
                      classIcon: classIcon,
                    ),
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

class _ClassInitialsBox extends StatelessWidget {
  final String initials;
  final Color classColor;
  final IconData classIcon;

  const _ClassInitialsBox({
    required this.initials,
    required this.classColor,
    required this.classIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: classColor.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: classColor.withAlpha(50), width: 1),
      ),
      child: Center(
        child: Icon(
          classIcon,
          size: 30,
          color: classColor,
        ),
      ),
    );
  }
}
