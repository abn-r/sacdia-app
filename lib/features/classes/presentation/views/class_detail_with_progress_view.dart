import 'dart:async';
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/animations/page_transitions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/class_module_detail.dart';
import '../../domain/entities/class_requirement.dart';
import '../../domain/entities/class_with_progress.dart';
import '../providers/classes_providers.dart';
import '../widgets/module_expansion_tile.dart';
import '../widgets/progress_ring.dart';
import 'requirement_detail_view.dart';

/// Vista de avances de clase — rediseño handoff (Variante B).
///
/// Layout top → bottom:
///   NavBar · HeroCard · PillsRow · SearchBar · SectionLabel · ModulesList.
/// Pull-to-refresh, skeleton loading, empty/error states.
class ClassDetailWithProgressView extends ConsumerWidget {
  final int classId;

  const ClassDetailWithProgressView({
    super.key,
    required this.classId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classAsync = ref.watch(classWithProgressProvider(classId));

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: classAsync.when(
          loading: () => const _SkeletonBody(),
          error: (error, _) => _ErrorBody(
            message: error.toString().replaceFirst('Exception: ', ''),
            onRetry: () => ref.invalidate(classWithProgressProvider(classId)),
          ),
          data: (classWithProgress) => _ClassBody(
            classWithProgress: classWithProgress,
            classId: classId,
            onRefresh: () async =>
                ref.invalidate(classWithProgressProvider(classId)),
          ),
        ),
      ),
    );
  }
}

// ── Body con datos ─────────────────────────────────────────────────────────────

class _ClassBody extends StatefulWidget {
  final ClassWithProgress classWithProgress;
  final int classId;
  final Future<void> Function() onRefresh;

  const _ClassBody({
    required this.classWithProgress,
    required this.classId,
    required this.onRefresh,
  });

  @override
  State<_ClassBody> createState() => _ClassBodyState();
}

class _ClassBodyState extends State<_ClassBody> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  String _query = '';
  Timer? _debounce;
  bool _searchFocused = false;

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(() {
      setState(() => _searchFocused = _searchFocusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _query = value);
    });
  }

  /// Filtra módulos + requerimientos según la query.
  /// Un módulo se incluye si su nombre coincide (con todos sus reqs)
  /// o si tiene requerimientos cuyo nombre / descripción coincida.
  List<ClassModuleDetail> get _filteredModules {
    if (_query.isEmpty) return widget.classWithProgress.modules;
    final q = _query.toLowerCase();
    final result = <ClassModuleDetail>[];
    for (final module in widget.classWithProgress.modules) {
      if (module.name.toLowerCase().contains(q)) {
        result.add(module);
        continue;
      }
      final matchingReqs = module.requirements
          .where((r) =>
              r.name.toLowerCase().contains(q) ||
              (r.description?.toLowerCase().contains(q) ?? false))
          .toList();
      if (matchingReqs.isNotEmpty) {
        result.add(module.copyWithRequirements(matchingReqs));
      }
    }
    return result;
  }

  /// Suggestion terms for the empty-search state.
  List<String> get _suggestions {
    final names = widget.classWithProgress.modules.map((m) => m.name).toList();
    return names.take(3).toList();
  }

  void _openRequirementDetail(ClassRequirement requirement) {
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

  @override
  Widget build(BuildContext context) {
    final classData = widget.classWithProgress;
    final filteredModules = _filteredModules;
    final hasQuery = _query.isNotEmpty;
    final noResults = hasQuery && filteredModules.isEmpty;

    return RefreshIndicator(
      color: AppColors.coral500,
      onRefresh: widget.onRefresh,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          // ── NavBar ────────────────────────────────────────────────────────
          SliverToBoxAdapter(child: _NavBar()),

          // ── HeroCard + PillsRow + SearchBar + SectionLabel ────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HeroCard(classData: classData),
                  _PillsRow(classData: classData),
                  _SearchBar(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    isFocused: _searchFocused,
                    hasQuery: hasQuery,
                    onChanged: _onSearchChanged,
                    onClear: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                  ),
                  if (!noResults)
                    const _SectionLabel(text: 'MÓDULOS'),
                ],
              ),
            ),
          ),

          // ── Empty search state ─────────────────────────────────────────────
          if (noResults)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: _NoResultsCard(
                  query: _query,
                  suggestions: _suggestions,
                  onSuggestionTap: (term) {
                    _searchController.text = term;
                    setState(() => _query = term);
                  },
                ),
              ),
            )

          // ── Modules list inside a single card ──────────────────────────────
          else if (classData.modules.isEmpty)
            const SliverToBoxAdapter(child: _EmptyModules())
          else
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: _ModulesCard(
                  modules: filteredModules,
                  onRequirementTap: _openRequirementDetail,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── NavBar ─────────────────────────────────────────────────────────────────────

class _NavBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      color: AppColors.canvas,
      child: Row(
        children: [
          // Back button 36×36
          SizedBox(
            width: 36,
            height: 36,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.maybePop(context),
              child: Center(
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowLeft01,
                  size: 20,
                  color: AppColors.ink800,
                ),
              ),
            ),
          ),
          // Title centered
          const Expanded(
            child: Text(
              'Clase',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.ink900,
              ),
            ),
          ),
          // Spacer to balance back button
          const SizedBox(width: 36, height: 36),
        ],
      ),
    );
  }
}

// ── HeroCard ───────────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  final ClassWithProgress classData;

  const _HeroCard({required this.classData});

  @override
  Widget build(BuildContext context) {
    final pct = classData.completionPercent;
    final validated = classData.completedRequirements;
    final total = classData.totalRequirements;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.ink150),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left side
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Eyebrow
                Text(
                  '${classData.name.toUpperCase()} · AVANCE',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink400,
                    letterSpacing: 0.88,
                  ),
                ),
                const SizedBox(height: 4),
                // Big percentage
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '$pct',
                        style: const TextStyle(
                          fontSize: 44,
                          fontWeight: FontWeight.w800,
                          color: AppColors.coral500,
                          height: 1,
                          letterSpacing: -1.3,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      const TextSpan(
                        text: '%',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.coral500,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                // Sub text
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.ink500,
                    ),
                    children: [
                      TextSpan(
                        text: '$validated',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink800,
                        ),
                      ),
                      TextSpan(text: ' de $total requisitos validados'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          // Right: 56×56 donut
          HeroDonut(progress: classData.completionRatio),
        ],
      ),
    );
  }
}

// ── PillsRow ───────────────────────────────────────────────────────────────────

class _PillsRow extends StatelessWidget {
  final ClassWithProgress classData;

  const _PillsRow({required this.classData});

  @override
  Widget build(BuildContext context) {
    // Count by status
    int validated = 0, sent = 0, observed = 0, rejected = 0, pending = 0;
    for (final m in classData.modules) {
      for (final r in m.requirements) {
        switch (r.status) {
          case RequirementStatus.validado:
            validated++;
            break;
          case RequirementStatus.enviado:
            sent++;
            break;
          case RequirementStatus.observado:
            observed++;
            break;
          case RequirementStatus.rechazado:
            rejected++;
            break;
          case RequirementStatus.pendiente:
            pending++;
            break;
        }
      }
    }

    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        clipBehavior: Clip.none,
        children: [
          _StatusPill(
            color: AppColors.validatedColor,
            bg: AppColors.validatedBg,
            label: 'Validados',
            count: validated,
          ),
          const SizedBox(width: 6),
          _StatusPill(
            color: AppColors.sentColor,
            bg: AppColors.sentBg,
            label: 'Enviados',
            count: sent,
          ),
          const SizedBox(width: 6),
          _StatusPill(
            color: AppColors.observedColor,
            bg: AppColors.observedBg,
            label: 'Observados',
            count: observed,
          ),
          const SizedBox(width: 6),
          _StatusPill(
            color: AppColors.rejectedColor,
            bg: AppColors.rejectedBg,
            label: 'Rechazados',
            count: rejected,
          ),
          const SizedBox(width: 6),
          _StatusPill(
            color: AppColors.pendingColor,
            bg: AppColors.pendingBg,
            label: 'Pendientes',
            count: pending,
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final Color color;
  final Color bg;
  final String label;
  final int count;

  const _StatusPill({
    required this.color,
    required this.bg,
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$count',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.ink800,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: AppColors.ink600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── SearchBar ──────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isFocused;
  final bool hasQuery;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.isFocused,
    required this.hasQuery,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.only(top: 12, bottom: 18),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(isFocused ? 14 : 12),
        border: Border.all(
          color: isFocused ? AppColors.coral500 : AppColors.ink150,
        ),
        boxShadow: isFocused
            ? [
                BoxShadow(
                  color: AppColors.coral500.withValues(alpha: 0.08),
                  blurRadius: 0,
                  spreadRadius: 4,
                )
              ]
            : null,
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          HugeIcon(
            icon: HugeIcons.strokeRoundedSearch01,
            size: 16,
            color: isFocused ? AppColors.coral500 : AppColors.ink400,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              style: const TextStyle(
                fontSize: 13.5,
                color: AppColors.ink800,
              ),
              decoration: const InputDecoration(
                hintText: 'Buscar requerimiento o módulo…',
                hintStyle: TextStyle(
                  fontSize: 13.5,
                  color: AppColors.ink400,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          if (hasQuery)
            GestureDetector(
              onTap: onClear,
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedCancel01,
                  size: 16,
                  color: AppColors.ink400,
                ),
              ),
            )
          else
            const SizedBox(width: 12),
        ],
      ),
    );
  }
}

// ── Section label ──────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.ink400,
          letterSpacing: 1.32,
        ),
      ),
    );
  }
}

// ── Modules card ───────────────────────────────────────────────────────────────

class _ModulesCard extends StatelessWidget {
  final List<ClassModuleDetail> modules;
  final void Function(ClassRequirement) onRequirementTap;

  const _ModulesCard({
    required this.modules,
    required this.onRequirementTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.ink150),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < modules.length; i++) ...[
              if (i > 0)
                const Divider(
                  color: AppColors.ink100,
                  height: 1,
                  thickness: 1,
                ),
              ModuleDetailRow(
                module: modules[i],
                // First module expanded by default
                initiallyExpanded: i == 0,
                onRequirementTap: onRequirementTap,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── No results card ────────────────────────────────────────────────────────────

class _NoResultsCard extends StatelessWidget {
  final String query;
  final List<String> suggestions;
  final void Function(String) onSuggestionTap;

  const _NoResultsCard({
    required this.query,
    required this.suggestions,
    required this.onSuggestionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.ink150),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Illustration circle
          Container(
            width: 88,
            height: 88,
            decoration: const BoxDecoration(
              color: AppColors.canvas,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: CustomPaint(
                size: const Size(64, 64),
                painter: _SearchIllustrationPainter(),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Title
          const Text(
            'No encontramos coincidencias',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.ink900,
            ),
          ),

          const SizedBox(height: 6),

          // Subtitle
          const SizedBox(
            width: 260,
            child: Text(
              'Prueba con otras palabras o revisa los módulos uno por uno desde la lista completa.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.ink500,
                height: 1.45,
              ),
            ),
          ),

          const SizedBox(height: 22),

          // Suggestions section
          if (suggestions.isNotEmpty) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: const Text(
                'SUGERENCIAS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink400,
                  letterSpacing: 0.88,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: suggestions.map((term) {
                  return GestureDetector(
                    onTap: () => onSuggestionTap(term),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.coral50,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppColors.coral100),
                      ),
                      child: Text(
                        term,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.coral700,
                        ),
                      ),
                    ),
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

class _SearchIllustrationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.44, size.height * 0.44);
    const outerRadius = 18.0;
    const innerRadius = 12.0;
    const strokeWidth = 3.0;

    // Outer circle (lens)
    final outerPaint = Paint()
      ..color = AppColors.ink200
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, outerRadius, outerPaint);

    // Inner fill (coral50)
    final innerFill = Paint()
      ..color = AppColors.coral50
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, innerRadius, innerFill);

    // Handle
    final handlePaint = Paint()
      ..color = AppColors.ink200
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      center + const Offset(12, 12),
      center + const Offset(20, 20),
      handlePaint,
    );

    // "?" text
    final tp = TextPainter(
      text: const TextSpan(
        text: '?',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.coral500,
          height: 1,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      center - Offset(tp.width / 2, tp.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Skeleton loading ───────────────────────────────────────────────────────────

class _SkeletonBody extends StatelessWidget {
  const _SkeletonBody();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _NavBar(),
          const SizedBox(height: 8),
          _SkeletonBox(height: 108, radius: 20),
          const SizedBox(height: 12),
          Row(
            children: List.generate(
              5,
              (i) => Padding(
                padding: EdgeInsets.only(right: i < 4 ? 6 : 0),
                child: _SkeletonBox(width: 90, height: 36, radius: 999),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _SkeletonBox(height: 44, radius: 12),
          const SizedBox(height: 18),
          _SkeletonBox(height: 200, radius: 16),
        ],
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const _SkeletonBox({
    this.width,
    required this.height,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.ink100,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

// ── Empty modules ──────────────────────────────────────────────────────────────

class _EmptyModules extends StatelessWidget {
  const _EmptyModules();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedSchool,
            size: 48,
            color: AppColors.ink400,
          ),
          const SizedBox(height: 12),
          Text(
            'classes.detail_with_progress.empty_modules_title'.tr(),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.ink500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'classes.detail_with_progress.empty_modules_body'.tr(),
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.ink400,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Error state ────────────────────────────────────────────────────────────────

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
              color: AppColors.rejectedColor,
            ),
            const SizedBox(height: 16),
            Text(
              'classes.detail_with_progress.error_loading'.tr(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.ink900,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(fontSize: 13, color: AppColors.ink500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.coral500,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'Reintentar',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
