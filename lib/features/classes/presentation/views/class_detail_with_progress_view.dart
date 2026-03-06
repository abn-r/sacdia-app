import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

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
                // Header card con progreso
                _ClassHeaderCard(classWithProgress: classWithProgress),

                // Resumen de requerimientos
                _ProgressSummaryRow(classWithProgress: classWithProgress),

                const SizedBox(height: 8),

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
                  return _ModuleSection(
                    module: module,
                    classId: classId,
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

// ── Header card ────────────────────────────────────────────────────────────────

class _ClassHeaderCard extends StatelessWidget {
  final ClassWithProgress classWithProgress;

  const _ClassHeaderCard({required this.classWithProgress});

  @override
  Widget build(BuildContext context) {
    final percentage = classWithProgress.completionPercent;
    final classColor = _classColor(classWithProgress.name);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [classColor, classColor.withValues(alpha: 0.75)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: classColor.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nombre + icono
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icono o imagen de la clase
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: classWithProgress.imageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(
                          classWithProgress.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => HugeIcon(
                            icon: HugeIcons.strokeRoundedSchool,
                            size: 28,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : HugeIcon(
                        icon: HugeIcons.strokeRoundedSchool,
                        size: 28,
                        color: Colors.white,
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      classWithProgress.name,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                    ),
                    if (classWithProgress.description != null &&
                        classWithProgress.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        classWithProgress.description!,
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
            progress: classWithProgress.completionRatio,
            height: 8,
            trackColor: Colors.white.withValues(alpha: 0.25),
            useGradient: false,
            color: Colors.white,
            showShimmer: false,
          ),
          const SizedBox(height: 14),

          // Stats row
          Row(
            children: [
              _HeaderStat(
                icon: HugeIcons.strokeRoundedStar,
                value:
                    '${classWithProgress.earnedPoints} / ${classWithProgress.totalPoints}',
                label: 'pts',
                iconColor: AppColors.accent,
              ),
              const SizedBox(width: 20),
              _HeaderStat(
                icon: HugeIcons.strokeRoundedCheckList,
                value:
                    '${classWithProgress.completedRequirements} / ${classWithProgress.totalRequirements}',
                label: 'requerimientos',
                iconColor: Colors.white,
              ),
            ],
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

class _HeaderStat extends StatelessWidget {
  final List<List<dynamic>> icon;
  final String value;
  final String label;
  final Color iconColor;

  const _HeaderStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        HugeIcon(icon: icon, size: 14, color: iconColor),
        const SizedBox(width: 5),
        Text(
          '$value $label',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

// ── Resumen de progreso ─────────────────────────────────────────────────────────

class _ProgressSummaryRow extends StatelessWidget {
  final ClassWithProgress classWithProgress;

  const _ProgressSummaryRow({required this.classWithProgress});

  @override
  Widget build(BuildContext context) {
    final total = classWithProgress.totalRequirements;
    final validated = classWithProgress.completedRequirements;
    final submitted = classWithProgress.submittedRequirements;
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
            label: 'Enviados',
            color: AppColors.sacBlue,
            bgColor: const Color(0xFFEFF6FF),
            context: context,
          ),
          const SizedBox(width: 8),
          _SummaryChip(
            count: validated,
            label: 'Validados',
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
                        ? HugeIcon(
                            icon: HugeIcons.strokeRoundedCheckmarkCircle01,
                            size: 20,
                            color: Colors.white,
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
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: widget.module.completionRatio,
                            minHeight: 4,
                            backgroundColor:
                                c.borderLight,
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
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.only(top: 4, bottom: 4),
                itemCount: widget.module.requirements.length,
                itemBuilder: (context, i) {
                  final requirement = widget.module.requirements[i];
                  return RequirementCard(
                    requirement: requirement,
                    onTap: () => _openRequirementDetail(context, requirement),
                  );
                },
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
      MaterialPageRoute(
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
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedSchool,
            size: 56,
            color: context.sac.textTertiary,
          ),
          const SizedBox(height: 12),
          Text(
            'No hay modulos disponibles para esta clase.',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: context.sac.textSecondary,
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
