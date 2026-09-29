import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/animations/sac_state_swap.dart';
import 'package:sacdia_app/core/animations/staggered_list_animation.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/sac_progress_bar.dart';
import 'package:sacdia_app/core/widgets/sac_back_button.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';
import 'package:sacdia_app/core/widgets/sac_tweened_bar.dart';
import 'package:sacdia_app/features/certifications/domain/entities/certification_progress.dart';

import '../providers/certifications_providers.dart';

/// Vista de progreso detallado de una certificación.
///
/// Acordeón por módulo, checkbox por sección (toggle via PATCH).
/// Barra de progreso por módulo y global.
/// Secciones completadas en verde, pendientes en gris.
///
/// NOTA: el endpoint de progreso (`GET .../certifications/:certificationId/
/// progress`) sigue keyed por `certificationId`, pero las rutas de ejecución
/// (requisitos, evidencias y cierre) usan el contrato del plan base basado en
/// `enrollmentId` (`.../certification-enrollments/:enrollmentId/...`), por lo
/// que [enrollmentId] debe propagarse a esas pantallas.
class CertificationProgressView extends ConsumerWidget {
  final int enrollmentId;
  final int certificationId;

  const CertificationProgressView({
    super.key,
    required this.enrollmentId,
    required this.certificationId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(
      certificationProgressProvider(certificationId),
    );
    final c = context.sac;

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: progressAsync.when(
          loading: () => const Center(child: SacLoading()),
          error: (error, _) => _ErrorBody(
            message: error.toString().replaceFirst('Exception: ', ''),
            onRetry: () =>
                ref.invalidate(certificationProgressProvider(certificationId)),
          ),
          data: (progress) => _ProgressBody(
            progress: progress,
            enrollmentId: enrollmentId,
            certificationId: certificationId,
          ),
        ),
      ),
    );
  }
}

// ── Progress Body ─────────────────────────────────────────────────────────────

class _ProgressBody extends ConsumerWidget {
  final CertificationProgress progress;
  final int enrollmentId;
  final int certificationId;

  const _ProgressBody({
    required this.progress,
    required this.enrollmentId,
    required this.certificationId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;

    return RefreshIndicator(
      color: SacAccent.of(context).color,
      onRefresh: () async {
        ref.invalidate(certificationProgressProvider(certificationId));
      },
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          // AppBar
          SliverAppBar(
            automaticallyImplyLeading: false,
            leading: sacAutoBackButton(context),
            pinned: true,
            expandedHeight: 0,
            backgroundColor: c.background,
            surfaceTintColor: Colors.transparent,
            title: Text(
              progress.certificationName,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: c.text,
                  ),
              overflow: TextOverflow.ellipsis,
            ),
            centerTitle: false,
          ),

          // Header con progreso global
          SliverToBoxAdapter(
            child: _GlobalProgressCard(
              progress: progress,
              onCloseoutTap: () => context.push(
                RouteNames.certificationCloseoutPath(
                  certificationId,
                  enrollmentId: enrollmentId,
                  certificationName: progress.certificationName,
                ),
              ),
            ),
          ),

          // Título sección
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'certifications.progress.modules_title'.tr(),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: c.text,
                    ),
              ),
            ),
          ),

          // Módulos con acordeón
          if (progress.modules.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Center(
                  child: Text(
                    'certifications.progress.no_modules'.tr(),
                    style: TextStyle(fontSize: 14, color: c.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final module = progress.modules[index];
                  return StaggeredListItem(
                    index: index,
                    child: _ModuleProgressSection(
                      module: module,
                      certificationId: certificationId,
                      enrollmentId: enrollmentId,
                    ),
                  );
                },
                childCount: progress.modules.length,
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

// ── Global Progress Card ──────────────────────────────────────────────────────

class _GlobalProgressCard extends StatelessWidget {
  final CertificationProgress progress;
  final VoidCallback onCloseoutTap;

  const _GlobalProgressCard({
    required this.progress,
    required this.onCloseoutTap,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = progress.progressPercentage;
    final isComplete = progress.completionStatus.toLowerCase() == 'completed';
    final completedModules = progress.modules
        .where((m) =>
            m.completedSections == m.totalSections && m.totalSections > 0)
        .length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isComplete
              ? [AppColors.secondary, AppColors.secondaryDark]
              : [SacAccent.of(context).color, SacAccent.of(context).dark],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isComplete ? AppColors.secondary : SacAccent.of(context).color)
                .withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HugeIcon(
                icon: isComplete
                    ? HugeIcons.strokeRoundedCheckmarkCircle02
                    : HugeIcons.strokeRoundedCertificate01,
                size: 22,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isComplete
                      ? 'certifications.progress.completed'.tr()
                      : 'certifications.progress.in_progress'.tr(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              Text(
                '${percentage.toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SacProgressBar(
            progress: percentage / 100,
            height: 8,
            trackColor: Colors.white.withValues(alpha: 0.25),
            useGradient: false,
            color: Colors.white,
            showShimmer: false,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedCheckList,
                size: 14,
                color: Colors.white70,
              ),
              const SizedBox(width: 5),
              Text(
                'certifications.progress.modules_completed'.tr(namedArgs: {
                  'completed': '$completedModules',
                  'total': '${progress.modules.length}',
                }),
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (isComplete) ...[
            const SizedBox(height: 14),
            SacButton(
              text: 'certifications.progress.closeout_cta'.tr(),
              icon: HugeIcons.strokeRoundedCertificate01,
              variant: SacButtonVariant.secondary,
              fullWidth: true,
              backgroundColor: Colors.white,
              textColor: AppColors.secondaryDark,
              onPressed: onCloseoutTap,
            ),
          ],
        ],
      ),
    );
  }
}

// ── Module Progress Section ───────────────────────────────────────────────────

class _ModuleProgressSection extends ConsumerStatefulWidget {
  final ModuleProgress module;
  final int certificationId;
  final int enrollmentId;

  const _ModuleProgressSection({
    required this.module,
    required this.certificationId,
    required this.enrollmentId,
  });

  @override
  ConsumerState<_ModuleProgressSection> createState() =>
      _ModuleProgressSectionState();
}

class _ModuleProgressSectionState
    extends ConsumerState<_ModuleProgressSection> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final module = widget.module;
    final isComplete = module.completedSections == module.totalSections &&
        module.totalSections > 0;
    final completionRatio = module.totalSections > 0
        ? module.completedSections / module.totalSections
        : 0.0;

    final colorDuration = SacMotion.reduceMotionOf(context)
        ? SacMotion.reducedFade
        : SacMotion.standard;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: AnimatedContainer(
              duration: colorDuration,
              curve: SacMotion.easeOut,
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              decoration: BoxDecoration(
                color: isComplete ? AppColors.secondaryLight : c.surfaceVariant,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: colorDuration,
                    curve: SacMotion.easeOut,
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color:
                          isComplete ? AppColors.secondary : SacAccent.of(context).color,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SacStateSwap(
                      duration: SacMotion.standard,
                      child: isComplete
                          ? const HugeIcon(
                              key: ValueKey('cert-module-done'),
                              icon: HugeIcons.strokeRoundedCheckmarkCircle01,
                              size: 20,
                              color: Colors.white,
                            )
                          : Text(
                              '${module.completedSections}/${module.totalSections}',
                              key: ValueKey(
                                'cert-module-${module.completedSections}-${module.totalSections}',
                              ),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedDefaultTextStyle(
                          duration: colorDuration,
                          curve: SacMotion.easeOut,
                          style: (Theme.of(context).textTheme.titleSmall ??
                                  const TextStyle())
                              .copyWith(
                            fontWeight: FontWeight.w700,
                            color:
                                isComplete ? AppColors.secondaryDark : c.text,
                          ),
                          child: Text(module.moduleName),
                        ),
                        const SizedBox(height: 4),
                        SacTweenedBar(
                          value: completionRatio,
                          minHeight: 4,
                          backgroundColor: c.borderLight,
                          color: isComplete
                              ? AppColors.secondary
                              : SacAccent.of(context).color,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  HugeIcon(
                    icon: _expanded
                        ? HugeIcons.strokeRoundedArrowUp01
                        : HugeIcons.strokeRoundedArrowDown01,
                    size: 18,
                    color: c.textTertiary,
                  ),
                ],
              ),
            ),
          ),

          // Secciones expandibles con checkboxes
          if (_expanded) ...[
            if (module.sections.isEmpty)
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  'certifications.progress.no_sections_module'.tr(),
                  style: TextStyle(fontSize: 13, color: c.textSecondary),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: module.sections.map((section) {
                    return _SectionCheckTile(
                      section: section,
                      certificationId: widget.certificationId,
                      moduleId: widget.module.moduleId,
                      enrollmentId: widget.enrollmentId,
                    );
                  }).toList(),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ── Section Check Tile ────────────────────────────────────────────────────────

class _SectionCheckTile extends ConsumerStatefulWidget {
  final SectionProgress section;
  final int certificationId;
  final int moduleId;
  final int enrollmentId;

  const _SectionCheckTile({
    required this.section,
    required this.certificationId,
    required this.moduleId,
    required this.enrollmentId,
  });

  @override
  ConsumerState<_SectionCheckTile> createState() => _SectionCheckTileState();
}

class _SectionCheckTileState extends ConsumerState<_SectionCheckTile> {
  bool _isLoading = false;
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  Future<void> _toggleSection() async {
    if (_isLoading) return;
    HapticFeedback.selectionClick();
    setState(() => _isLoading = true);

    try {
      await ref
          .read(
              sectionProgressNotifierProvider(widget.certificationId).notifier)
          .updateSection(
            moduleId: widget.moduleId,
            sectionId: widget.section.sectionId,
            completed: !widget.section.completed,
          );
      ref.invalidate(certificationProgressProvider(widget.certificationId));
      ref.invalidate(userCertificationsProvider);
    } catch (e) {
      if (mounted) {
        SacSnackBar.show(context, e.toString().replaceFirst('Exception: ', ''),
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final reduce = SacMotion.reduceMotionOf(context);
    final isCompleted = widget.section.completed;
    final labelColor = isCompleted ? AppColors.secondary : c.text;

    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleSection,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              AnimatedScale(
                scale: (!reduce && _pressed) ? SacMotion.pressScale : 1,
                duration: SacMotion.press,
                curve: SacMotion.easeOut,
                child: AnimatedContainer(
                  duration: reduce ? SacMotion.reducedFade : SacMotion.standard,
                  curve: SacMotion.easeOut,
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color:
                        isCompleted ? AppColors.secondary : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isCompleted ? AppColors.secondary : c.border,
                      width: 2,
                    ),
                  ),
                  child: SacStateSwap(
                    duration: SacMotion.press,
                    child: _sectionCheckFace(
                      completed: isCompleted,
                      loading: _isLoading,
                      idleColor: c.textTertiary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AnimatedDefaultTextStyle(
                  duration: reduce ? SacMotion.reducedFade : SacMotion.press,
                  curve: SacMotion.easeOut,
                  style: TextStyle(
                    fontSize: 13,
                    color: labelColor,
                    fontWeight: isCompleted ? FontWeight.w600 : FontWeight.w400,
                    decoration: isCompleted
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                    decorationColor: AppColors.secondary,
                  ),
                  child: Text(widget.section.sectionName),
                ),
              ),
              SacStateSwap(
                duration: SacMotion.press,
                child: isCompleted
                    ? const Padding(
                        key: ValueKey('section-trail-on'),
                        padding: EdgeInsets.only(right: 4),
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedCheckmarkCircle01,
                          size: 16,
                          color: AppColors.secondary,
                        ),
                      )
                    : const SizedBox.shrink(key: ValueKey('section-trail-off')),
              ),
              SacPressable(
                listenOnly: true,
                child: IconButton(
                  enableFeedback: false,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'certifications.progress.open_requirement'.tr(),
                  onPressed: () => context.push(
                    RouteNames.certificationRequirementDetailPath(
                      widget.certificationId,
                      widget.section.sectionId,
                      enrollmentId: widget.enrollmentId,
                    ),
                  ),
                  icon: HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowRight01,
                    size: 16,
                    color: c.textTertiary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _sectionCheckFace({
  required bool completed,
  required bool loading,
  required Color idleColor,
}) {
  if (loading) {
    return SizedBox(
      key: ValueKey(
        completed ? 'section-check-loading-on' : 'section-check-loading-off',
      ),
      width: 14,
      height: 14,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: completed ? Colors.white : idleColor,
      ),
    );
  }
  if (completed) {
    return const HugeIcon(
      key: ValueKey('section-check-on'),
      icon: HugeIcons.strokeRoundedTick02,
      size: 14,
      color: Colors.white,
    );
  }
  return const SizedBox.shrink(key: ValueKey('section-check-off'));
}

// ── Error Body ────────────────────────────────────────────────────────────────

class _ErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBody({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedAlert02,
              size: 56,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            Text(
              'certifications.progress.load_error'.tr(),
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: context.sac.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SacButton.primary(
              text: 'common.retry'.tr(),
              icon: HugeIcons.strokeRoundedRefresh,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
