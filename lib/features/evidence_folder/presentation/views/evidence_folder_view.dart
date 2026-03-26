import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/animations/page_transitions.dart';
import '../../../../core/animations/staggered_list_animation.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_loading.dart';
import '../../../../core/widgets/sac_progress_bar.dart';
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
          loading: () => const Center(child: SacLoading()),
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
    final percentage =
        (folder.completionRatio * 100).toStringAsFixed(0);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nombre + estado
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      folder.name,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                    ),
                    if (folder.description != null &&
                        folder.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        folder.description!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.75),
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: folder.isOpen
                      ? Colors.white.withValues(alpha: 0.2)
                      : AppColors.accent.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    HugeIcon(
                      icon: folder.isOpen
                          ? HugeIcons.strokeRoundedLock
                          : HugeIcons.strokeRoundedLocked,
                      size: 12,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      folder.isOpen ? 'Abierta' : 'Cerrada',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Progreso global
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progreso general',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
              Text(
                '$percentage%',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SacProgressBar(
            progress: folder.completionRatio,
            height: 8,
            trackColor: Colors.white.withValues(alpha: 0.25),
            useGradient: false,
            color: Colors.white,
            showShimmer: false,
          ),
          const SizedBox(height: 14),

          // Puntos
          Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedStar,
                size: 14,
                color: AppColors.accent,
              ),
              const SizedBox(width: 5),
              Text(
                '${folder.earnedPoints} / ${folder.maxPoints} puntos',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
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
    final total = folder.sections.length;
    final validated = folder.validatedCount;   // validado + evaluated
    final submitted = folder.submittedCount;   // enviado + underEvaluation
    final pending = total - validated - submitted;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _SummaryChip(
            count: pending,
            label: 'Pendientes',
            color: AppColors.accent,
            bgColor: AppColors.accentLight,
            context: context,
          ),
          const SizedBox(width: 8),
          _SummaryChip(
            count: submitted,
            label: 'Enviadas',
            color: AppColors.sacBlue,
            bgColor: Theme.of(context).brightness == Brightness.dark
                ? AppColors.statusInfoBgDark
                : AppColors.statusInfoBgLight,
            context: context,
          ),
          const SizedBox(width: 8),
          _SummaryChip(
            count: validated,
            label: 'Validadas',
            color: AppColors.secondary,
            bgColor: AppColors.secondaryLight,
            context: context,
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final int count;
  final String label;
  final Color color;
  final Color bgColor;
  final BuildContext context;

  const _SummaryChip({
    required this.count,
    required this.label,
    required this.color,
    required this.bgColor,
    required this.context,
  });

  @override
  Widget build(BuildContext _) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
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
