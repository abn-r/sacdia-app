import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/staggered_list_animation.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/sac_progress_bar.dart';
import 'package:sacdia_app/features/certifications/domain/entities/certification_progress.dart';

import '../providers/certifications_providers.dart';

/// Vista de progreso detallado de una certificación.
///
/// Acordeón por módulo, checkbox por sección (toggle via PATCH).
/// Barra de progreso por módulo y global.
/// Secciones completadas en verde, pendientes en gris.
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
      certificationProgressProvider(enrollmentId),
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
                ref.invalidate(certificationProgressProvider(enrollmentId)),
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
      color: AppColors.primary,
      onRefresh: () async {
        ref.invalidate(certificationProgressProvider(enrollmentId));
      },
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          // AppBar
          SliverAppBar(
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
            child: _GlobalProgressCard(progress: progress),
          ),

          // Título sección
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Módulos',
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
                    'No hay módulos en esta certificación.',
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

  const _GlobalProgressCard({required this.progress});

  @override
  Widget build(BuildContext context) {
    final percentage = progress.progressPercentage;
    final isComplete = progress.completionStatus.toLowerCase() == 'completed';
    final completedModules = progress.modules
        .where((m) => m.completedSections == m.totalSections && m.totalSections > 0)
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
              : [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isComplete ? AppColors.secondary : AppColors.primary)
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
                  isComplete ? 'Certificación completada' : 'En progreso',
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
                '$completedModules / ${progress.modules.length} módulos completados',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Module Progress Section ───────────────────────────────────────────────────

class _ModuleProgressSection extends ConsumerStatefulWidget {
  final ModuleProgress module;
  final int certificationId;

  const _ModuleProgressSection({
    required this.module,
    required this.certificationId,
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
          // Header del módulo
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              decoration: BoxDecoration(
                color: isComplete ? AppColors.secondaryLight : c.surfaceVariant,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  // Icono de estado del módulo
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isComplete ? AppColors.secondary : AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: isComplete
                        ? HugeIcon(
                            icon: HugeIcons.strokeRoundedCheckmarkCircle01,
                            size: 20,
                            color: Colors.white,
                          )
                        : Center(
                            child: Text(
                              '${module.completedSections}/${module.totalSections}',
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
                        Text(
                          module.moduleName,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: isComplete
                                    ? AppColors.secondaryDark
                                    : c.text,
                              ),
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: completionRatio,
                            minHeight: 4,
                            backgroundColor: c.borderLight,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isComplete
                                  ? AppColors.secondary
                                  : AppColors.primary,
                            ),
                          ),
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
                  'No hay secciones en este módulo.',
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

  const _SectionCheckTile({
    required this.section,
    required this.certificationId,
    required this.moduleId,
  });

  @override
  ConsumerState<_SectionCheckTile> createState() => _SectionCheckTileState();
}

class _SectionCheckTileState extends ConsumerState<_SectionCheckTile> {
  bool _isLoading = false;

  Future<void> _toggleSection() async {
    if (_isLoading) return;
    HapticFeedback.selectionClick();
    setState(() => _isLoading = true);

    try {
      await ref
          .read(sectionProgressNotifierProvider(widget.certificationId).notifier)
          .updateSection(
            moduleId: widget.moduleId,
            sectionId: widget.section.sectionId,
            completed: !widget.section.completed,
          );
      ref.invalidate(certificationProgressProvider(widget.certificationId));
      ref.invalidate(userCertificationsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final isCompleted = widget.section.completed;

    return InkWell(
      onTap: _toggleSection,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            // Checkbox visual
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: isCompleted ? AppColors.secondary : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isCompleted ? AppColors.secondary : c.border,
                  width: 2,
                ),
              ),
              child: isCompleted
                  ? _isLoading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_rounded,
                          size: 14, color: Colors.white)
                  : _isLoading
                      ? SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: c.textTertiary,
                          ),
                        )
                      : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.section.sectionName,
                style: TextStyle(
                  fontSize: 13,
                  color: isCompleted ? AppColors.secondary : c.text,
                  fontWeight:
                      isCompleted ? FontWeight.w600 : FontWeight.w400,
                  decoration: isCompleted
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                  decorationColor: AppColors.secondary,
                ),
              ),
            ),
            if (isCompleted)
              HugeIcon(
                icon: HugeIcons.strokeRoundedCheckmarkCircle01,
                size: 16,
                color: AppColors.secondary,
              ),
          ],
        ),
      ),
    );
  }
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
              'Error al cargar el progreso',
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
              text: 'Reintentar',
              icon: HugeIcons.strokeRoundedRefresh,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
