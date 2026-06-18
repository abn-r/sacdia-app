import 'dart:async';
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/animations/page_transitions.dart';
import '../../../../core/auth/club_role_names.dart';
import '../../../../core/config/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_dialog.dart';
import '../../../../core/widgets/sac_top_bar.dart';
import '../../../investiture/domain/entities/investiture_status.dart';
import '../../../investiture/presentation/providers/investiture_providers.dart';
import '../../../members/presentation/providers/members_providers.dart';
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
  final int? enrollmentId;

  const ClassDetailWithProgressView({
    super.key,
    required this.classId,
    this.enrollmentId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressQuery = ClassProgressQuery(
      classId: classId,
      enrollmentId: enrollmentId,
    );
    final classAsync = ref.watch(classWithProgressProvider(progressQuery));

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: const SacTopBar(
        title: 'Clase',
        centerTitle: true,
        backgroundColor: AppColors.canvas,
        borderColor: AppColors.ink150,
      ),
      body: SafeArea(
        top: false,
        child: classAsync.when(
          loading: () => const _SkeletonBody(),
          error: (error, _) => _ErrorBody(
            message: error.toString().replaceFirst('Exception: ', ''),
            onRetry: () =>
                ref.invalidate(classWithProgressProvider(progressQuery)),
          ),
          data: (classWithProgress) => _ClassBody(
            classWithProgress: classWithProgress,
            classId: classId,
            enrollmentId: enrollmentId ?? classWithProgress.enrollmentId,
            onRefresh: () async =>
                ref.invalidate(classWithProgressProvider(progressQuery)),
          ),
        ),
      ),
    );
  }
}

// ── Body con datos ─────────────────────────────────────────────────────────────

class _ClassBody extends ConsumerStatefulWidget {
  final ClassWithProgress classWithProgress;
  final int classId;
  final int? enrollmentId;
  final Future<void> Function() onRefresh;

  const _ClassBody({
    required this.classWithProgress,
    required this.classId,
    this.enrollmentId,
    required this.onRefresh,
  });

  @override
  ConsumerState<_ClassBody> createState() => _ClassBodyState();
}

class _ClassBodyState extends ConsumerState<_ClassBody> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _query = ValueNotifier<String>('');
  final _searchFocused = ValueNotifier<bool>(false);
  Timer? _debounce;
  List<ClassModuleDetail>? _cachedModulesSource;
  String? _cachedQuery;
  List<ClassModuleDetail>? _cachedFilteredModules;

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(() {
      _searchFocused.value = _searchFocusNode.hasFocus;
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    _searchFocused.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (mounted) _query.value = value;
    });
  }

  /// Filtra módulos + requerimientos según la query.
  /// Un módulo se incluye si su nombre coincide (con todos sus reqs)
  /// o si tiene requerimientos cuyo nombre / descripción coincida.
  List<ClassModuleDetail> _filteredModules(String query) {
    final modules = widget.classWithProgress.modules;
    final cached = _cachedFilteredModules;
    if (cached != null &&
        identical(_cachedModulesSource, modules) &&
        _cachedQuery == query) {
      return cached;
    }

    if (query.isEmpty) {
      _cachedModulesSource = modules;
      _cachedQuery = query;
      _cachedFilteredModules = modules;
      return modules;
    }

    final q = query.toLowerCase();
    final result = <ClassModuleDetail>[];
    for (final module in modules) {
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
    _cachedModulesSource = modules;
    _cachedQuery = query;
    _cachedFilteredModules = result;
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
          enrollmentId:
              widget.enrollmentId ?? widget.classWithProgress.enrollmentId,
          isClassExpired: widget.classWithProgress.isExpired,
        ),
      ),
    );
  }

  Future<void> _submitInvestiture({
    required int enrollmentId,
    required int clubId,
  }) async {
    final confirmed = await SacDialog.show(
      context,
      title: 'Enviar a validación',
      content:
          'Tu clase quedará bloqueada mientras el equipo responsable revisa la investidura.',
      highlight: 'Requisitos validados: 100%',
      confirmLabel: 'Enviar',
      cancelLabel: 'Cancelar',
      icon: HugeIcons.strokeRoundedMailSend01,
      iconColor: AppColors.coral700,
      iconBackgroundColor: AppColors.coral50,
    );

    if (confirmed != true || !mounted) return;

    final notifier =
        ref.read(submitForValidationNotifierProvider(enrollmentId).notifier);
    final ok = await notifier.submit(clubId: clubId);

    if (!mounted) return;

    if (ok) {
      ref
        ..invalidate(classWithProgressProvider(ClassProgressQuery(
          classId: widget.classId,
          enrollmentId: widget.enrollmentId,
        )))
        ..invalidate(userClassesProvider)
        ..invalidate(investitureHistoryProvider(enrollmentId));
    }

    final state = ref.read(submitForValidationNotifierProvider(enrollmentId));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Clase enviada a validación de investidura.'
              : state.errorMessage ??
                  'No pudimos enviar la clase a validación. Intenta nuevamente.',
        ),
        backgroundColor: ok ? AppColors.coral700 : AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final classData = widget.classWithProgress;
    final resolvedEnrollmentId = widget.enrollmentId ?? classData.enrollmentId;
    final investitureStatus = _investitureStatusOf(classData);
    final showInvestitureCard = _shouldShowInvestitureCard(
      classData,
      enrollmentId: resolvedEnrollmentId,
    );
    final clubContextAsync =
        showInvestitureCard ? ref.watch(clubContextProvider) : null;
    final submitState = showInvestitureCard && resolvedEnrollmentId != null
        ? ref.watch(submitForValidationNotifierProvider(resolvedEnrollmentId))
        : null;

    return RefreshIndicator(
      color: AppColors.coral500,
      onRefresh: widget.onRefresh,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          // ── HeroCard + PillsRow + SearchBar + SectionLabel ────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HeroCard(classData: classData),
                  if (classData.isExpired) const _ExpiredTrajectoryBanner(),
                  _PillsRow(classData: classData),
                  if (showInvestitureCard)
                    _InvestitureCompletionCard(
                      status: investitureStatus,
                      clubContextAsync: clubContextAsync!,
                      submitState: submitState,
                      onSubmit: (clubId) => _submitInvestiture(
                        enrollmentId: resolvedEnrollmentId!,
                        clubId: clubId,
                      ),
                      onHistoryTap: () => context.push(
                        RouteNames.investitureHistoryPath(
                          resolvedEnrollmentId!.toString(),
                        ),
                      ),
                    ),
                  ValueListenableBuilder<String>(
                    valueListenable: _query,
                    builder: (context, query, _) {
                      return ValueListenableBuilder<bool>(
                        valueListenable: _searchFocused,
                        builder: (context, isFocused, _) {
                          return _SearchBar(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            isFocused: isFocused,
                            hasQuery: query.isNotEmpty,
                            onChanged: _onSearchChanged,
                            onClear: () {
                              _searchController.clear();
                              _query.value = '';
                            },
                          );
                        },
                      );
                    },
                  ),
                  ValueListenableBuilder<String>(
                    valueListenable: _query,
                    builder: (context, query, _) {
                      final filteredModules = _filteredModules(query);
                      final noResults =
                          query.isNotEmpty && filteredModules.isEmpty;
                      return noResults
                          ? const SizedBox.shrink()
                          : const _SectionLabel(text: 'MÓDULOS');
                    },
                  ),
                ],
              ),
            ),
          ),

          // ── Empty search state ─────────────────────────────────────────────
          ValueListenableBuilder<String>(
            valueListenable: _query,
            builder: (context, query, _) {
              final filteredModules = _filteredModules(query);
              final noResults = query.isNotEmpty && filteredModules.isEmpty;

              if (noResults) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    child: _NoResultsCard(
                      query: query,
                      suggestions: _suggestions,
                      onSuggestionTap: (term) {
                        _searchController.text = term;
                        _query.value = term;
                      },
                    ),
                  ),
                );
              }

              // ── Modules list inside a single card ──────────────────────────
              if (classData.modules.isEmpty) {
                return const SliverToBoxAdapter(child: _EmptyModules());
              }

              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: _ModulesCard(
                    modules: filteredModules,
                    onRequirementTap: _openRequirementDetail,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

InvestitureStatus _investitureStatusOf(ClassWithProgress classData) {
  final raw = classData.investitureStatus;
  if (raw == null || raw.trim().isEmpty) {
    return InvestitureStatus.inProgress;
  }
  return InvestitureStatus.fromString(raw);
}

bool _shouldShowInvestitureCard(
  ClassWithProgress classData, {
  required int? enrollmentId,
}) {
  if (enrollmentId == null || classData.isExpired) return false;
  if (classData.totalRequirements == 0) return false;
  return classData.completedRequirements == classData.totalRequirements;
}

bool _canSubmitInvestiture(InvestitureStatus status) {
  return status == InvestitureStatus.inProgress ||
      status == InvestitureStatus.rejected;
}

bool _isInvestitureReviewer(ClubContext? context) {
  final role = context?.roleName?.trim().toLowerCase();
  return role == ClubRoleNames.director || role == ClubRoleNames.counselor;
}

class _InvestitureCompletionCard extends StatelessWidget {
  final InvestitureStatus status;
  final AsyncValue<ClubContext?> clubContextAsync;
  final InvestitureActionState? submitState;
  final ValueChanged<int> onSubmit;
  final VoidCallback onHistoryTap;

  const _InvestitureCompletionCard({
    required this.status,
    required this.clubContextAsync,
    required this.submitState,
    required this.onSubmit,
    required this.onHistoryTap,
  });

  @override
  Widget build(BuildContext context) {
    final style = _InvestitureCardStyle.forStatus(status);
    final canSubmit = _canSubmitInvestiture(status);
    final clubContext = clubContextAsync.valueOrNull;
    final canCurrentUserSubmit = _isInvestitureReviewer(clubContext);
    final isContextLoading = clubContextAsync.isLoading;
    final hasContextError = clubContextAsync.hasError;
    final isSubmitting = submitState?.isLoading ?? false;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12, bottom: 2),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: style.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.paper.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: style.foreground.withValues(alpha: 0.14),
                  ),
                ),
                child: Center(
                  child: HugeIcon(
                    icon: style.icon,
                    size: 21,
                    color: style.foreground,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      style.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink900,
                        height: 1.18,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      style.description,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.ink600,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _InvestitureStatusChip(status: status),
            ],
          ),
          const SizedBox(height: 14),
          if (canSubmit && canCurrentUserSubmit)
            SacButton.primary(
              text: status == InvestitureStatus.rejected
                  ? 'Reenviar a validación'
                  : 'Enviar a validación',
              icon: HugeIcons.strokeRoundedSent,
              isLoading: isSubmitting,
              isEnabled: !isSubmitting,
              onPressed: () => onSubmit(clubContext!.clubId),
              backgroundColor: AppColors.coral700,
              borderRadius: 14,
              fontSize: 14,
            )
          else if (canSubmit)
            _InvestitureHelperNote(
              text: isContextLoading
                  ? 'Preparando el contexto del club…'
                  : hasContextError
                      ? 'No pudimos confirmar tu rol activo. Intenta cambiar de sección o recargar.'
                      : status == InvestitureStatus.rejected
                          ? 'La solicitud fue observada. Un consejero o director podrá reenviarla después de corregir el avance.'
                          : 'Tu clase ya está lista. Un consejero o director debe enviarla a validación de investidura.',
              color: style.foreground,
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _InvestitureHelperNote(
                  text: style.helperText,
                  color: style.foreground,
                ),
                const SizedBox(height: 10),
                SacButton.outline(
                  text: 'Ver historial',
                  icon: HugeIcons.strokeRoundedClock01,
                  onPressed: onHistoryTap,
                  textColor: style.foreground,
                  backgroundColor: AppColors.paper.withValues(alpha: 0.64),
                  borderRadius: 14,
                  fontSize: 13,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _InvestitureHelperNote extends StatelessWidget {
  final String text;
  final Color color;

  const _InvestitureHelperNote({
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.paper.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
          height: 1.35,
        ),
      ),
    );
  }
}

class _InvestitureStatusChip extends StatelessWidget {
  final InvestitureStatus status;

  const _InvestitureStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final style = _InvestitureCardStyle.forStatus(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.paper.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: style.foreground.withValues(alpha: 0.16)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 116),
        child: Text(
          status.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: style.foreground,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _InvestitureCardStyle {
  final String title;
  final String description;
  final Color background;
  final Color border;
  final Color foreground;
  final dynamic icon;
  final String helperText;

  const _InvestitureCardStyle({
    required this.title,
    required this.description,
    required this.background,
    required this.border,
    required this.foreground,
    required this.icon,
    required this.helperText,
  });

  factory _InvestitureCardStyle.forStatus(InvestitureStatus status) {
    switch (status) {
      case InvestitureStatus.rejected:
        return _InvestitureCardStyle(
          title: 'Reenvío disponible',
          description:
              'La solicitud fue observada. Si ya corregiste el avance, vuelve a enviarla.',
          helperText:
              'Revisa las observaciones en el historial antes de reenviar la clase a validación.',
          background: AppColors.rejectedBg,
          border: AppColors.rejectedColor.withValues(alpha: 0.24),
          foreground: AppColors.rejectedDark,
          icon: HugeIcons.strokeRoundedAlert02,
        );
      case InvestitureStatus.submittedForValidation:
      case InvestitureStatus.clubApproved:
      case InvestitureStatus.coordinatorApproved:
      case InvestitureStatus.fieldApproved:
      case InvestitureStatus.approved:
        return _InvestitureCardStyle(
          title: status == InvestitureStatus.submittedForValidation
              ? 'Clase enviada a validación'
              : 'Validación en proceso',
          description:
              'Tu clase ya fue enviada y será revisada por el equipo responsable.',
          helperText:
              'El proceso de revisión puede demorar aproximadamente de 1 a 2 semanas. Te avisaremos cuando haya una actualización.',
          background: AppColors.sentBg,
          border: AppColors.sentColor.withValues(alpha: 0.22),
          foreground: AppColors.sentDark,
          icon: HugeIcons.strokeRoundedClock01,
        );
      case InvestitureStatus.investido:
        return _InvestitureCardStyle(
          title: 'Investidura registrada',
          description:
              'Esta clase ya quedó reconocida formalmente en el historial del miembro.',
          helperText:
              'La investidura ya fue registrada. Puedes consultar el historial para ver el detalle del proceso.',
          background: AppColors.validatedBg,
          border: AppColors.validatedColor.withValues(alpha: 0.22),
          foreground: AppColors.validatedDark,
          icon: HugeIcons.strokeRoundedCheckmarkCircle02,
        );
      case InvestitureStatus.inProgress:
      case InvestitureStatus.expired:
        return _InvestitureCardStyle(
          title: 'Clase lista para investidura',
          description:
              'Todos los requisitos están validados. El siguiente paso es enviarla a validación.',
          helperText:
              'Tu clase ya está lista. Un consejero o director debe enviarla a validación de investidura.',
          background: AppColors.coral50,
          border: AppColors.coral200,
          foreground: AppColors.coral700,
          icon: HugeIcons.strokeRoundedCheckmarkCircle02,
        );
    }
  }
}

class _ExpiredTrajectoryBanner extends StatelessWidget {
  const _ExpiredTrajectoryBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.35)),
      ),
      child: Text(
        'classes.requirement_detail.expired_banner'.tr(),
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: AppColors.errorDark,
          height: 1.35,
        ),
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
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          if (hasQuery)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onClear,
              child: SizedBox(
                width: 44,
                height: 44,
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedCancel01,
                  size: 16,
                  color: AppColors.ink400,
                ),
              ),
            )
          else
            const SizedBox(width: 12, height: 44),
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
    final firstPendingModuleIndex = modules.indexWhere(
      (module) =>
          module.requirements.isNotEmpty &&
          module.completedCount < module.requirements.length,
    );

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
                initiallyExpanded: i == firstPendingModuleIndex,
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
              child: RepaintBoundary(
                child: CustomPaint(
                  size: const Size(64, 64),
                  painter: _SearchIllustrationPainter(),
                ),
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
          _SkeletonBox(height: 108, radius: 20),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              children: List.generate(
                5,
                (i) => Padding(
                  padding: EdgeInsets.only(right: i < 4 ? 6 : 0),
                  child: _SkeletonBox(width: 90, height: 36, radius: 999),
                ),
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
