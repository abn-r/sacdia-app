import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/staggered_list_animation.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/utils/responsive.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import '../providers/classes_providers.dart';
import '../sheets/enroll_previous_class_sheet.dart';
import '../widgets/class_card.dart';
import 'class_detail_with_progress_view.dart';

// ── Top-level helper — reachable from AppBar and from ClassesListViewBody ───────

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

/// Vista de lista de clases — tab principal del bottom nav.
///
/// Layout (top → bottom):
///   1. AppBar "Clases" con acción "Inscribirme" (solo si tiene club activo)
///   2. Chip de entrada al Roadmap
///   3. Sección "Clase actual" (primer elemento de la lista)
///   4. Sección "Otras clases" (resto de elementos)
///
/// Internamente delega el cuerpo a [ClassesListViewBody] para que también
/// pueda ser embebido en otro Scaffold sin doble Scaffold.
class ClassesListView extends ConsumerWidget {
  const ClassesListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final hasActiveClub = ref
            .watch(authNotifierProvider.select((v) => v.valueOrNull))
            ?.authorization
            ?.activeGrant
            ?.sectionId !=
        null;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        title: const Text('Clases'),
        automaticallyImplyLeading: false,
        actions: [
          if (hasActiveClub)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: OutlinedButton.icon(
                onPressed: () => _openEnrollSheet(context),
                icon: HugeIcon(
                  icon: HugeIcons.strokeRoundedBookmarkAdd02,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                label: Text(
                  'classes.list.enroll_cta_short'.tr(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  shape: const StadiumBorder(),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  minimumSize: const Size(0, 40),
                  tapTargetSize: MaterialTapTargetSize.padded,
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
        ],
      ),
      body: const ClassesListViewBody(),
    );
  }
}

/// Body de la lista de clases, sin Scaffold ni AppBar propios.
/// Usar este widget cuando se embebe dentro de otro Scaffold.
class ClassesListViewBody extends ConsumerWidget {
  const ClassesListViewBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classesAsync = ref.watch(userClassesProvider);
    final hPad = Responsive.horizontalPadding(context);
    final c = context.sac;
    final theme = Theme.of(context);

    final user = ref.watch(
      authNotifierProvider.select((v) => v.valueOrNull),
    );
    final hasActiveClub = user?.authorization?.activeGrant?.sectionId != null;

    return classesAsync.when(
      data: (classes) {
        if (classes.isEmpty) {
          return _EmptyBody(
            hPad: hPad,
            hasActiveClub: hasActiveClub,
            onEnroll: () => _openEnrollSheet(context),
            c: c,
          );
        }

        // Split: current class (index 0) vs others
        final currentClass = classes.first;
        final otherClasses =
            classes.length > 1 ? classes.sublist(1) : <dynamic>[];

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            ref.invalidate(userClassesProvider);
          },
          child: ListView(
            padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 32),
            children: [
              // ── Roadmap entry chip ─────────────────────────────────────────
              _RoadmapChip(hPad: hPad),
              const SizedBox(height: 20),

              // ── Section: Clase actual ──────────────────────────────────────
              Text(
                'classes.list.section_current'.tr(),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: c.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              StaggeredListItem(
                index: 0,
                initialDelay: const Duration(milliseconds: 80),
                staggerDelay: const Duration(milliseconds: 65),
                child: Consumer(
                  builder: (context, progressRef, _) {
                    final progressAsync = progressRef
                        .watch(classWithProgressProvider(currentClass.id));
                    final progress = progressAsync.whenOrNull(
                          data: (cwp) => cwp.completionRatio,
                        ) ??
                        0.0;
                    return ClassCard(
                      progressiveClass: currentClass,
                      progress: progress,
                      isCurrent: true,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ClassDetailWithProgressView(
                              classId: currentClass.id,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              // ── Section: Otras clases ──────────────────────────────────────
              if (otherClasses.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'classes.list.section_others'.tr(),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: c.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                for (int i = 0; i < otherClasses.length; i++)
                  StaggeredListItem(
                    index: i + 1,
                    initialDelay: const Duration(milliseconds: 80),
                    staggerDelay: const Duration(milliseconds: 65),
                    child: Consumer(
                      builder: (context, progressRef, _) {
                        final progressiveClass = otherClasses[i];
                        final progressAsync = progressRef.watch(
                            classWithProgressProvider(progressiveClass.id));
                        final progress = progressAsync.whenOrNull(
                              data: (cwp) => cwp.completionRatio,
                            ) ??
                            0.0;
                        return ClassCard(
                          progressiveClass: progressiveClass,
                          progress: progress,
                          isCurrent: false,
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
                  ),
              ],
            ],
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
                'classes.list.error_loading'.tr(),
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
                text: 'common.retry'.tr(),
                icon: HugeIcons.strokeRoundedRefresh,
                onPressed: () {
                  ref.invalidate(userClassesProvider);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Roadmap chip ──────────────────────────────────────────────────────────────

class _RoadmapChip extends StatelessWidget {
  final double hPad;

  const _RoadmapChip({required this.hPad});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(RouteNames.homeClassesRoadmap),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedRoute01,
                    size: 22,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'classes.list.roadmap_chip_title'.tr(),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'classes.list.roadmap_chip_subtitle'.tr(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Inline enroll button ──────────────────────────────────────────────────────

class _EnrollButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _EnrollButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: const HugeIcon(
          icon: HugeIcons.strokeRoundedAdd01,
          size: 20,
          color: Colors.white,
        ),
        label: Text('classes.list.enroll_cta'.tr()),
      ),
    );
  }
}

// ── Empty body ────────────────────────────────────────────────────────────────

class _EmptyBody extends StatelessWidget {
  final double hPad;
  final bool hasActiveClub;
  final VoidCallback onEnroll;
  final SacColors c;

  const _EmptyBody({
    required this.hPad,
    required this.hasActiveClub,
    required this.onEnroll,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 32),
      children: [
        _RoadmapChip(hPad: hPad),
        const SizedBox(height: 40),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedSchool,
                size: 56,
                color: c.textTertiary,
              ),
              const SizedBox(height: 12),
              Text(
                'classes.list.empty'.tr(),
                style: TextStyle(
                  fontSize: 16,
                  color: c.textSecondary,
                ),
              ),
            ],
          ),
        ),
        if (hasActiveClub) ...[
          const SizedBox(height: 32),
          _EnrollButton(onPressed: onEnroll),
        ],
      ],
    );
  }
}
