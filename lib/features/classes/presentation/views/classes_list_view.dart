import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/staggered_list_animation.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/responsive.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import '../providers/classes_providers.dart';
import '../sheets/enroll_previous_class_sheet.dart';
import '../widgets/class_card.dart';
import 'class_detail_with_progress_view.dart';

/// Vista de lista de clases - Estilo "Scout Vibrante"
///
/// Sin AppBar (tab del bottom nav), titulo inline,
/// ClassCards con SacProgressBar y badge "Clase actual".
/// Items animan con stagger slide-up al cargar.
class ClassesListView extends ConsumerWidget {
  const ClassesListView({super.key});

  void _openEnrollSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const EnrollPreviousClassSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classesAsync = ref.watch(userClassesProvider);
    final hPad = Responsive.horizontalPadding(context);
    final c = context.sac;

    final user = ref.watch(
      authNotifierProvider.select((v) => v.valueOrNull),
    );
    final hasActiveClub = user?.authorization?.activeGrant?.sectionId != null;

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: classesAsync.when(
          data: (classes) {
            if (classes.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    HugeIcon(
                        icon: HugeIcons.strokeRoundedSchool,
                        size: 56,
                        color: c.textTertiary),
                    const SizedBox(height: 12),
                    Text(
                      'No tienes clases asignadas',
                      style: TextStyle(
                        fontSize: 16,
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async {
                ref.invalidate(userClassesProvider);
              },
              child: ListView.builder(
                padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 24),
                itemCount: classes.length + 1, // +1 para el header
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: HugeIcon(
                              icon: HugeIcons.strokeRoundedSchool,
                              size: 22,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Mis Clases',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                          if (hasActiveClub)
                            Tooltip(
                              message: 'Inscribir clase anterior',
                              child: IconButton(
                                onPressed: () => _openEnrollSheet(context),
                                icon: HugeIcon(
                                  icon: HugeIcons.strokeRoundedBookmarkAdd02,
                                  size: 24,
                                  color: AppColors.primary,
                                ),
                                style: IconButton.styleFrom(
                                  backgroundColor: AppColors.primaryLight,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }

                  final classIndex = index - 1;
                  final progressiveClass = classes[classIndex];

                  return StaggeredListItem(
                    index: classIndex,
                    initialDelay: const Duration(milliseconds: 80),
                    staggerDelay: const Duration(milliseconds: 65),
                    child: Consumer(
                      builder: (context, progressRef, _) {
                        final progressAsync = progressRef.watch(
                            classWithProgressProvider(progressiveClass.id));
                        final progress = progressAsync.whenOrNull(
                              data: (cwp) => cwp.completionRatio,
                            ) ??
                            0.0;
                        return ClassCard(
                          progressiveClass: progressiveClass,
                          progress: progress,
                          isCurrent: classIndex == 0,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ClassDetailWithProgressView(
                                  classId: progressiveClass.id,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  );
                },
              ),
            );
          },
          loading: () => const Center(child: SacLoading()),
          error: (error, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  HugeIcon(
                      icon: HugeIcons.strokeRoundedAlert02,
                      size: 56,
                      color: AppColors.error),
                  const SizedBox(height: 16),
                  Text(
                    'Error al cargar clases',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error.toString().replaceFirst('Exception: ', ''),
                    style: TextStyle(fontSize: 14, color: c.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  SacButton.primary(
                    text: 'Reintentar',
                    icon: HugeIcons.strokeRoundedRefresh,
                    onPressed: () {
                      ref.invalidate(userClassesProvider);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
