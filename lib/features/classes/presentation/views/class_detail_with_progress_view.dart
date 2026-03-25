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
import '../../../validation/presentation/widgets/validation_section.dart';
import '../../../validation/domain/entities/validation.dart';

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

class _ClassBody extends StatefulWidget {
  final ClassWithProgress classWithProgress;
  final int classId;

  const _ClassBody({
    required this.classWithProgress,
    required this.classId,
  });

  @override
  State<_ClassBody> createState() => _ClassBodyState();
}

class _ClassBodyState extends State<_ClassBody> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Filtra los modulos y sus requerimientos segun el query de busqueda.
  /// Un modulo se muestra si su nombre matchea o si algun requerimiento matchea.
  /// Si solo matchean requerimientos, el modulo se muestra con esos requerimientos filtrados.
  List<ClassModuleDetail> get _filteredModules {
    if (_query.isEmpty) return widget.classWithProgress.modules;

    final q = _query.toLowerCase();
    final result = <ClassModuleDetail>[];

    for (final module in widget.classWithProgress.modules) {
      final moduleNameMatches = module.name.toLowerCase().contains(q);

      final matchingRequirements = module.requirements
          .where((r) =>
              r.name.toLowerCase().contains(q) ||
              (r.description?.toLowerCase().contains(q) ?? false))
          .toList();

      if (moduleNameMatches) {
        result.add(module);
      } else if (matchingRequirements.isNotEmpty) {
        result.add(module.copyWithRequirements(matchingRequirements));
      }
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final filteredModules = _filteredModules;

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
              widget.classWithProgress.name,
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
                const SizedBox(height: 8),

                // Progress card — compact
                _ProgressCard(classWithProgress: widget.classWithProgress),

                const SizedBox(height: 12),

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

                // Search bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _query = value),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: c.text,
                        ),
                    decoration: InputDecoration(
                      hintText: 'Buscar modulo o requerimiento...',
                      hintStyle: TextStyle(color: c.textTertiary),
                      prefixIcon: HugeIcon(
                        icon: HugeIcons.strokeRoundedSearch01,
                        size: 20,
                        color: c.textSecondary,
                      ),
                      suffixIcon: _query.isNotEmpty
                          ? GestureDetector(
                              onTap: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                              child: Icon(Icons.close_rounded,
                                  size: 18, color: c.textSecondary),
                            )
                          : null,
                      filled: true,
                      fillColor: c.surfaceVariant,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Modulos con sus requerimientos
          if (widget.classWithProgress.modules.isEmpty)
            SliverToBoxAdapter(child: _EmptyModules())
          else if (filteredModules.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
                child: Column(
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedSearch01,
                      size: 40,
                      color: c.textTertiary,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Sin resultados para "$_query"',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: c.textSecondary,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final module = filteredModules[index];
                  return StaggeredListItem(
                    index: index,
                    child: _ModuleSection(
                      module: module,
                      classId: widget.classId,
                    ),
                  );
                },
                childCount: filteredModules.length,
              ),
            ),

          // Validation section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: ValidationSection(
                entityType: ValidationEntityType.classProgress,
                entityId: widget.classId,
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

// ── Class identity section ─────────────────────────────────────────────────────

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
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
        boxShadow: [
          BoxShadow(
            color: c.shadow,
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress bar + percentage inline
          Row(
            children: [
              Expanded(
                child: SacProgressBar(
                  progress: classWithProgress.completionRatio,
                  height: 6,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$percentage%',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: c.text,
                    ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Compact stats row
          Row(
            children: [
              _CompactStat(
                icon: HugeIcons.strokeRoundedCheckList,
                color: AppColors.secondary,
                value: '$validated/$total',
                label: 'requisitos',
                context: context,
              ),
              Container(
                width: 1,
                height: 14,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                color: c.borderLight,
              ),
              _CompactStat(
                icon: HugeIcons.strokeRoundedClock01,
                color: AppColors.accent,
                value: '$pending',
                label: 'pend.',
                context: context,
              ),
              Container(
                width: 1,
                height: 14,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                color: c.borderLight,
              ),
              _CompactStat(
                icon: HugeIcons.strokeRoundedSent,
                color: AppColors.sacBlue,
                value: '$submitted',
                label: 'env.',
                context: context,
              ),
              Container(
                width: 1,
                height: 14,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                color: c.borderLight,
              ),
              _CompactStat(
                icon: HugeIcons.strokeRoundedCheckmarkCircle01,
                color: AppColors.secondary,
                value: '$validated',
                label: 'val.',
                context: context,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Compact stat ──────────────────────────────────────────────────────────────

class _CompactStat extends StatelessWidget {
  final List<List<dynamic>> icon;
  final Color color;
  final String value;
  final String label;
  final BuildContext context;

  const _CompactStat({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    required this.context,
  });

  @override
  Widget build(BuildContext _) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        HugeIcon(icon: icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          '$value ',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: context.sac.text,
              ),
        ),
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
