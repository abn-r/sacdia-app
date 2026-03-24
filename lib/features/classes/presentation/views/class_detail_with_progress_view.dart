import 'package:cached_network_image/cached_network_image.dart';
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
import '../../domain/entities/class_module_detail.dart';
import '../../domain/entities/class_requirement.dart';
import '../../domain/entities/class_with_progress.dart';
import '../providers/classes_providers.dart';
import '../widgets/requirement_card.dart';
import 'requirement_detail_view.dart';

/// Vista de clase progresiva con progreso detallado.
///
/// Muestra el encabezado con progreso global, la lista de modulos
/// con sus requerimientos, y permite navegar al detalle de cada requerimiento.
///
/// Sigue el patron identico al EvidenceFolderView de carpeta_evidencias.
class ClassDetailWithProgressView extends ConsumerWidget {
  final int classId;

  const ClassDetailWithProgressView({
    super.key,
    required this.classId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classAsync = ref.watch(classWithProgressProvider(classId));
    final c = context.sac;

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: classAsync.when(
          loading: () => const Center(child: SacLoading()),
          error: (error, _) => _ErrorBody(
            message: error.toString().replaceFirst('Exception: ', ''),
            onRetry: () =>
                ref.invalidate(classWithProgressProvider(classId)),
          ),
          data: (classWithProgress) => _ClassBody(
            classWithProgress: classWithProgress,
            classId: classId,
          ),
        ),
      ),
    );
  }
}

// ── Body cuando hay datos ──────────────────────────────────────────────────────

class _ClassBody extends StatelessWidget {
  final ClassWithProgress classWithProgress;
  final int classId;

  const _ClassBody({
    required this.classWithProgress,
    required this.classId,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        // El consumer padre invalida al volver
      },
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          // App bar
          SliverAppBar(
            pinned: true,
            expandedHeight: 0,
            backgroundColor: c.background,
            surfaceTintColor: Colors.transparent,
            title: Text(
              classWithProgress.name,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: c.text,
                  ),
              overflow: TextOverflow.ellipsis,
            ),
            centerTitle: false,
          ),

          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Class identity section — clean, no card wrapper
                _ClassIdentitySection(classWithProgress: classWithProgress),

                const SizedBox(height: 12),

                // Progress card — Apple Health style
                _ProgressCard(classWithProgress: classWithProgress),

                const SizedBox(height: 16),

                // Modulos header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text(
                    'Modulos y Requerimientos',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: c.text,
                        ),
                  ),
                ),
              ],
            ),
          ),

          // Modulos con sus requerimientos
          if (classWithProgress.modules.isEmpty)
            SliverToBoxAdapter(child: _EmptyModules())
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final module = classWithProgress.modules[index];
                  return StaggeredListItem(
                    index: index,
                    child: _ModuleSection(
                      module: module,
                      classId: classId,
                    ),
                  );
                },
                childCount: classWithProgress.modules.length,
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

// ── Class identity section ─────────────────────────────────────────────────────

class _ClassIdentitySection extends StatelessWidget {
  final ClassWithProgress classWithProgress;

  const _ClassIdentitySection({required this.classWithProgress});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final classColor = _classColor(classWithProgress.name);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icon container — tinted with class color
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: classColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: classWithProgress.imageUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: CachedNetworkImage(
                      imageUrl: classWithProgress.imageUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Center(
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedSchool,
                          size: 26,
                          color: classColor,
                        ),
                      ),
                    ),
                  )
                : Center(
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedSchool,
                      size: 26,
                      color: classColor,
                    ),
                  ),
          ),
          const SizedBox(width: 14),
          // Class name and description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  classWithProgress.name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: c.text,
                      ),
                ),
                if (classWithProgress.description != null &&
                    classWithProgress.description!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    classWithProgress.description!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: c.textSecondary,
                          height: 1.4,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Devuelve el color asociado al nombre de la clase progresiva.
  Color _classColor(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('amigo')) return AppColors.colorAmigo;
    if (lower.contains('companero') || lower.contains('compañero')) {
      return AppColors.colorCompanero;
    }
    if (lower.contains('explorador')) return AppColors.colorExplorador;
    if (lower.contains('orientador')) return AppColors.colorOrientador;
    if (lower.contains('viajero')) return AppColors.colorViajero;
    if (lower.contains('guia') || lower.contains('guía')) {
      return AppColors.colorGuia;
    }
    if (lower.contains('corderito')) return AppColors.colorCorderitos;
    if (lower.contains('castor')) return AppColors.colorCastores;
    if (lower.contains('abeja')) return AppColors.colorAbejas;
    if (lower.contains('rayo')) return AppColors.colorRayos;
    if (lower.contains('constructor')) return AppColors.colorConstructores;
    if (lower.contains('mano')) return AppColors.colorManos;
    return AppColors.primary;
  }
}

// ── Progress card ──────────────────────────────────────────────────────────────

class _ProgressCard extends StatelessWidget {
  final ClassWithProgress classWithProgress;

  const _ProgressCard({required this.classWithProgress});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final percentage = classWithProgress.completionPercent;
    final total = classWithProgress.totalRequirements;
    final validated = classWithProgress.completedRequirements;
    final submitted = classWithProgress.submittedRequirements;
    final pending = total - validated - submitted;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
        boxShadow: [
          BoxShadow(
            color: c.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress label + percentage
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progreso general',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: c.textSecondary,
                    ),
              ),
              Text(
                '$percentage%',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: c.text,
                    ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Progress bar — default gradient
          SacProgressBar(
            progress: classWithProgress.completionRatio,
            height: 8,
          ),

          const SizedBox(height: 16),

          // Stat pills row
          Row(
            children: [
              _StatPill(
                icon: HugeIcons.strokeRoundedStar,
                iconColor: AppColors.accent,
                value: '${classWithProgress.earnedPoints}/${classWithProgress.totalPoints}',
                label: 'puntos',
                context: context,
              ),
              const SizedBox(width: 16),
              _StatPill(
                icon: HugeIcons.strokeRoundedCheckList,
                iconColor: AppColors.secondary,
                value: '${classWithProgress.completedRequirements}/${classWithProgress.totalRequirements}',
                label: 'requisitos',
                context: context,
              ),
            ],
          ),

          const SizedBox(height: 12),

          Divider(height: 1, color: c.borderLight),

          const SizedBox(height: 12),

          // Count indicators row
          Row(
            children: [
              Expanded(
                child: _CountIndicator(
                  dotColor: AppColors.accent,
                  count: pending,
                  label: 'Pendientes',
                  context: context,
                ),
              ),
              Expanded(
                child: _CountIndicator(
                  dotColor: AppColors.sacBlue,
                  count: submitted,
                  label: 'Enviados',
                  context: context,
                ),
              ),
              Expanded(
                child: _CountIndicator(
                  dotColor: AppColors.secondary,
                  count: validated,
                  label: 'Validados',
                  context: context,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Stat pill ──────────────────────────────────────────────────────────────────

class _StatPill extends StatelessWidget {
  final List<List<dynamic>> icon;
  final Color iconColor;
  final String value;
  final String label;
  final BuildContext context;

  const _StatPill({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    required this.context,
  });

  @override
  Widget build(BuildContext _) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        HugeIcon(icon: icon, size: 14, color: iconColor),
        const SizedBox(width: 5),
        Text(
          '$value $label',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: context.sac.textSecondary,
              ),
        ),
      ],
    );
  }
}

// ── Count indicator ────────────────────────────────────────────────────────────

class _CountIndicator extends StatelessWidget {
  final Color dotColor;
  final int count;
  final String label;
  final BuildContext context;

  const _CountIndicator({
    required this.dotColor,
    required this.count,
    required this.label,
    required this.context,
  });

  @override
  Widget build(BuildContext _) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$count',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: context.sac.text,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: context.sac.textSecondary,
              ),
        ),
      ],
    );
  }
}

// ── Seccion de modulo con requerimientos ────────────────────────────────────────

class _ModuleSection extends StatefulWidget {
  final ClassModuleDetail module;
  final int classId;

  const _ModuleSection({required this.module, required this.classId});

  @override
  State<_ModuleSection> createState() => _ModuleSectionState();
}

class _ModuleSectionState extends State<_ModuleSection> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final isComplete = widget.module.completedCount == widget.module.requirements.length &&
        widget.module.requirements.isNotEmpty;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header del modulo
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                color: isComplete
                    ? AppColors.secondaryLight
                    : c.surfaceVariant,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  // Icono de modulo
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isComplete
                          ? AppColors.secondary
                          : AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: isComplete
                        ? Center(
                            child: HugeIcon(
                              icon: HugeIcons.strokeRoundedCheckmarkCircle01,
                              size: 20,
                              color: Colors.white,
                            ),
                          )
                        : Center(
                            child: Text(
                              '${widget.module.completedCount}/${widget.module.requirements.length}',
                              style: const TextStyle(
                                fontSize: 12,
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
                          widget.module.name,
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
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: widget.module.completionRatio
                                      .clamp(0.0, 1.0),
                                  minHeight: 4,
                                  backgroundColor: c.borderLight,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    isComplete
                                        ? AppColors.secondary
                                        : AppColors.primary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${(widget.module.completionRatio.clamp(0.0, 1.0) * 100).round()}%',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isComplete
                                    ? AppColors.secondary
                                    : AppColors.primary,
                              ),
                            ),
                          ],
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

          // Requerimientos del modulo
          if (_expanded) ...[
            if (widget.module.requirements.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No hay requerimientos en este modulo.',
                  style: TextStyle(
                    fontSize: 14,
                    color: c.textSecondary,
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 4),
                child: Column(
                  // shrinkWrap replaced: requirements per module are a small,
                  // fixed-count list inside a bounded Column — no virtualization
                  // needed; Column avoids the O(n²) layout cost of shrinkWrap.
                  mainAxisSize: MainAxisSize.min,
                  children: widget.module.requirements.map((requirement) {
                    return RequirementCard(
                      requirement: requirement,
                      onTap: () =>
                          _openRequirementDetail(context, requirement),
                    );
                  }).toList(),
                ),
              ),
          ],
        ],
      ),
    );
  }

  void _openRequirementDetail(
      BuildContext context, ClassRequirement requirement) {
    Navigator.push(
      context,
      SacSharedAxisRoute(
        builder: (_) => RequirementDetailView(
          requirement: requirement,
          classId: widget.classId,
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyModules extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedSchool,
            size: 48,
            color: c.textTertiary,
          ),
          const SizedBox(height: 12),
          Text(
            'Sin módulos aún',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: c.textSecondary,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Los módulos aparecerán cuando estén disponibles para esta clase.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: c.textTertiary,
                ),
            textAlign: TextAlign.center,
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
              'Error al cargar la clase',
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
