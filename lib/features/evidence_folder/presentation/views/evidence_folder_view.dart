import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/animations/page_transitions.dart';
import '../../../../core/animations/staggered_list_animation.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_progress_bar.dart';
import '../widgets/evidence_folder_loading_skeleton.dart';
import '../../domain/entities/evidence_folder.dart';
import '../../domain/entities/evidence_section.dart';
import '../providers/evidence_folder_providers.dart';
import '../widgets/folder_closed_banner.dart';
import '../widgets/section_card.dart';
import 'evidence_section_detail_view.dart';

/// Vista principal de la carpeta de evidencias.
///
/// Muestra el encabezado de la carpeta (estado, progreso, puntos),
/// el banner de carpeta cerrada cuando aplica, y la lista de secciones.
///
/// [clubSectionId] identifica el contexto de club activo.
class EvidenceFolderView extends ConsumerWidget {
  final String clubSectionId;

  const EvidenceFolderView({
    super.key,
    required this.clubSectionId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folderAsync =
        ref.watch(evidenceFolderProvider(clubSectionId));
    final c = context.sac;

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: folderAsync.when(
          loading: () => const EvidenceFolderLoadingSkeleton(),
          error: (error, _) => _ErrorBody(
            message: error.toString().replaceFirst('Exception: ', ''),
            onRetry: () =>
                ref.invalidate(evidenceFolderProvider(clubSectionId)),
          ),
          data: (folder) => _FolderBody(
            folder: folder,
            clubSectionId: clubSectionId,
          ),
        ),
      ),
    );
  }
}

// ── Body cuando hay datos ──────────────────────────────────────────────────────

class _FolderBody extends StatelessWidget {
  final EvidenceFolder folder;
  final String clubSectionId;

  const _FolderBody({
    required this.folder,
    required this.clubSectionId,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        // El consumer padre invalidará si el widget aún está montado;
        // aquí usamos una forma segura via ProviderScope.
      },
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          // App bar con título
          SliverAppBar(
            pinned: true,
            expandedHeight: 0,
            backgroundColor: c.background,
            surfaceTintColor: Colors.transparent,
            title: Text(
              'Carpeta de Evidencias',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: c.text,
                  ),
            ),
            centerTitle: false,
          ),

          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Banner evaluado / cerrado
                if (!folder.isOpen || folder.isEvaluated)
                  FolderClosedBanner(folder: folder),

                // Banner en evaluación (carpeta abierta pero bajo evaluación)
                if (folder.isOpen && folder.isUnderEvaluation)
                  _UnderEvaluationBanner(folder: folder),

                // Header card
                _FolderHeaderCard(folder: folder),

                // Progress summary
                _ProgressSummaryRow(folder: folder),

                const SizedBox(height: 8),

                // Sections header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Text(
                    'Secciones',
                    style:
                        Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: c.text,
                            ),
                  ),
                ),
              ],
            ),
          ),

          // Sections list
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final section = folder.sections[index];
                return StaggeredListItem(
                  index: index,
                  child: SectionCard(
                    section: section,
                    onTap: () => _openSectionDetail(context, section),
                  ),
                );
              },
              childCount: folder.sections.length,
            ),
          ),

          SliverToBoxAdapter(
            child: folder.sections.isEmpty
                ? _EmptySections()
                : const SizedBox(height: 32),
          ),
        ],
      ),
    );
  }

  void _openSectionDetail(BuildContext context, EvidenceSection section) {
    Navigator.push(
      context,
      SacSharedAxisRoute(
        builder: (_) => EvidenceSectionDetailView(
          section: section,
          folderIsOpen: folder.isOpen,
          clubSectionId: clubSectionId,
        ),
      ),
    );
  }
}

// ── Header card con nombre y estado de la carpeta ─────────────────────────────

class _FolderHeaderCard extends StatelessWidget {
  final EvidenceFolder folder;

  const _FolderHeaderCard({required this.folder});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final percentage = (folder.completionRatio * 100).toStringAsFixed(0);

    // Status badge colors
    final statusColor = folder.isOpen ? AppColors.secondary : AppColors.accent;
    final statusBg = folder.isOpen
        ? AppColors.secondaryLight
        : AppColors.accentLight;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nombre + estado en una fila compacta
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  folder.name,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: c.text,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    HugeIcon(
                      icon: folder.isOpen
                          ? HugeIcons.strokeRoundedLock
                          : HugeIcons.strokeRoundedLocked,
                      size: 11,
                      color: statusColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      folder.isOpen ? 'Abierta' : 'Cerrada',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (folder.description != null &&
              folder.description!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              folder.description!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: c.textSecondary,
                    height: 1.4,
                  ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          const SizedBox(height: 14),
          Divider(color: c.divider, height: 1),
          const SizedBox(height: 12),

          // Progreso + porcentaje inline
          Row(
            children: [
              Expanded(
                child: SacProgressBar(
                  progress: folder.completionRatio,
                  height: 5,
                  trackColor: c.border,
                  useGradient: false,
                  color: AppColors.secondary,
                  showShimmer: false,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$percentage%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: folder.completionRatio > 0
                      ? AppColors.secondary
                      : c.textTertiary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Puntos — inline, sutil
          Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedStar,
                size: 13,
                color: AppColors.accent,
              ),
              const SizedBox(width: 5),
              Text(
                '${folder.earnedPoints} / ${folder.maxPoints} pts',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: c.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Fila resumen de secciones ──────────────────────────────────────────────────

class _ProgressSummaryRow extends StatelessWidget {
  final EvidenceFolder folder;

  const _ProgressSummaryRow({required this.folder});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final total = folder.sections.length;
    final validated = folder.validatedCount;
    final submitted = folder.submittedCount;
    final pending = total - validated - submitted;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        children: [
          _StatPill(
            count: pending,
            label: 'Pendientes',
            color: AppColors.accent,
          ),
          const SizedBox(width: 8),
          _StatPill(
            count: submitted,
            label: 'Enviadas',
            color: AppColors.sacBlue,
          ),
          const SizedBox(width: 8),
          _StatPill(
            count: validated,
            label: 'Validadas',
            color: AppColors.secondary,
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final int count;
  final String label;
  final Color color;

  const _StatPill({
    required this.count,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: c.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: c.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Banner bajo evaluación ────────────────────────────────────────────────────

class _UnderEvaluationBanner extends StatelessWidget {
  final EvidenceFolder folder;

  const _UnderEvaluationBanner({required this.folder});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedAnalytics01,
                size: 22,
                color: const Color(0xFF92400E),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'En proceso de evaluación',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF92400E),
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'El evaluador del campo está revisando las evidencias de este club.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF92400E),
                        height: 1.45,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptySections extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedFolderOpen,
            size: 56,
            color: context.sac.textTertiary,
          ),
          const SizedBox(height: 12),
          Text(
            'No hay secciones disponibles',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(color: context.sac.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ── Error state ───────────────────────────────────────────────────────────────

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
              'Error al cargar la carpeta',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
