import 'dart:async';
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/animations/animated_counter.dart';
import '../../../../core/animations/motion_tokens.dart';
import '../../../../core/animations/page_transitions.dart';
import '../../../../core/auth/club_role_names.dart';
import '../../../../core/config/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_dialog.dart';
import '../../../../core/widgets/sac_network_image.dart';
import '../../../../core/widgets/sac_pressable.dart';
import '../../../../core/widgets/sac_top_bar.dart';
import '../../../investiture/domain/entities/investiture_status.dart';
import '../../../investiture/presentation/providers/investiture_providers.dart';
import '../../../members/presentation/providers/members_providers.dart';
import '../../domain/entities/class_honor.dart';
import '../../domain/entities/class_module_detail.dart';
import '../../domain/entities/class_prerequisite.dart';
import '../../domain/entities/class_requirement.dart';
import '../../domain/entities/class_with_progress.dart';
import '../../domain/entities/requirement_track.dart';
import '../providers/classes_providers.dart';
import '../widgets/class_identity_badge.dart';
import '../widgets/module_expansion_tile.dart';
import '../widgets/progress_ring.dart';
import '../widgets/requirement_card.dart';
import 'requirement_detail_view.dart';

/// Vista de avances de clase — rediseño handoff (Variante B).
///
/// Layout top → bottom:
///   NavBar · HeroCard · PillsRow · SearchBar · SectionLabel · ModulesList.
/// Pull-to-refresh, skeleton loading, empty/error states.
class ClassDetailWithProgressView extends ConsumerWidget {
  final int classId;
  final int? enrollmentId;
  final String? targetUserId;

  const ClassDetailWithProgressView({
    super.key,
    required this.classId,
    this.enrollmentId,
    this.targetUserId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressQuery = ClassProgressQuery(
      classId: classId,
      enrollmentId: enrollmentId,
      targetUserId: targetUserId,
    );
    final classAsync = ref.watch(classWithProgressProvider(progressQuery));
    final prerequisitesAsync = ref.watch(classDetailProvider(classId));
    final c = context.sac;

    return Scaffold(
      backgroundColor: c.canvas,
      appBar: SacTopBar(
        title: 'Clase',
        centerTitle: true,
        backgroundColor: c.canvas,
        borderColor: c.ink150,
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
            targetUserId: targetUserId,
            prerequisites:
                prerequisitesAsync.valueOrNull?.prerequisites ?? const [],
            onRefresh: () async {
              ref.invalidate(classWithProgressProvider(progressQuery));
              ref.invalidate(classDetailProvider(classId));
              ref.invalidate(classHonorsProvider(classId));
            },
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
  final String? targetUserId;
  final List<ClassPrerequisite> prerequisites;
  final Future<void> Function() onRefresh;

  const _ClassBody({
    required this.classWithProgress,
    required this.classId,
    this.enrollmentId,
    this.targetUserId,
    this.prerequisites = const [],
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

  _RequirementTrackBuckets _bucketByRequirementTrack(
    List<ClassModuleDetail> modules,
  ) {
    final basicModules = <ClassModuleDetail>[];
    final advancedRequirements = <ClassRequirement>[];
    final extraRequirements = <ClassRequirement>[];

    for (final module in modules) {
      final basicRequirements = <ClassRequirement>[];

      for (final requirement in module.requirements) {
        switch (requirement.requirementTrack) {
          case RequirementTrack.advanced:
            advancedRequirements.add(requirement);
            break;
          case RequirementTrack.extra:
            extraRequirements.add(requirement);
            break;
          case RequirementTrack.basic:
          case RequirementTrack.unknown:
          case null:
            basicRequirements.add(requirement);
            break;
        }
      }

      if (basicRequirements.isNotEmpty) {
        basicModules.add(
          module.copyWithRequirements(_sortedRequirements(basicRequirements)),
        );
      }
    }

    return _RequirementTrackBuckets(
      basicModules: basicModules,
      advancedRequirements: _sortedRequirements(advancedRequirements),
      extraRequirements: _sortedRequirements(extraRequirements),
    );
  }

  List<ClassRequirement> _sortedRequirements(
    List<ClassRequirement> requirements,
  ) {
    final sorted = List<ClassRequirement>.from(requirements);
    sorted.sort((a, b) {
      final aOrder = a.displayOrder ?? 1 << 20;
      final bOrder = b.displayOrder ?? 1 << 20;
      if (aOrder != bOrder) return aOrder.compareTo(bOrder);
      return a.name.compareTo(b.name);
    });
    return sorted;
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
          targetUserId: widget.targetUserId,
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
          targetUserId: widget.targetUserId,
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
    final classColor = AppColors.classColor(classData.name);
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
      color: classColor,
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
                  _HeroCard(classData: classData, classColor: classColor),
                  if (classData.isExpired) const _ExpiredTrajectoryBanner(),
                  if (widget.prerequisites.isNotEmpty)
                    _PrerequisitesBanner(prerequisites: widget.prerequisites),
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
                            accentColor: classColor,
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
                      final buckets =
                          _bucketByRequirementTrack(filteredModules);
                      final noResults = query.isNotEmpty &&
                          (filteredModules.isEmpty || buckets.isEmpty);
                      return noResults
                          ? const SizedBox.shrink()
                          : const SizedBox(height: 2);
                    },
                  ),
                ],
              ),
            ),
          ),

          // Especialidades arriba de los módulos: Guía Mayor ancla las
          // sugerencias a módulos y el carrusel al pie quedaba fuera de vista.
          SliverToBoxAdapter(
            child: _RecommendedHonorsSection(classId: widget.classId),
          ),

          // ── Empty search state ─────────────────────────────────────────────
          ValueListenableBuilder<String>(
            valueListenable: _query,
            builder: (context, query, _) {
              final filteredModules = _filteredModules(query);
              final buckets = _bucketByRequirementTrack(filteredModules);
              final noResults = query.isNotEmpty &&
                  (filteredModules.isEmpty || buckets.isEmpty);

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
                      accentColor: classColor,
                    ),
                  ),
                );
              }

              // ── Modules list inside a single card ──────────────────────────
              if (classData.modules.isEmpty || buckets.isEmpty) {
                return const SliverToBoxAdapter(child: _EmptyModules());
              }

              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: _RequirementTrackSections(
                    classId: widget.classId,
                    buckets: buckets,
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

class _RequirementTrackBuckets {
  final List<ClassModuleDetail> basicModules;
  final List<ClassRequirement> advancedRequirements;
  final List<ClassRequirement> extraRequirements;

  const _RequirementTrackBuckets({
    required this.basicModules,
    required this.advancedRequirements,
    required this.extraRequirements,
  });

  bool get isEmpty =>
      basicModules.isEmpty &&
      advancedRequirements.isEmpty &&
      extraRequirements.isEmpty;
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
  return classData.isInvestitureEligibleByTrackOrLegacy;
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
    final showHistory = status != InvestitureStatus.inProgress;
    final showSubmit = canSubmit && canCurrentUserSubmit;
    final title = _title(canSubmit: canSubmit);
    final subtitle = _subtitle(
      canSubmit: canSubmit,
      canCurrentUserSubmit: canCurrentUserSubmit,
      isContextLoading: isContextLoading,
      hasContextError: hasContextError,
    );

    final card = Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: style.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _InvestitureStatusRow(
            style: style,
            title: title,
            subtitle: subtitle,
            showChevron: showHistory,
            onTap: showSubmit ? onHistoryTap : null,
          ),
          if (showSubmit)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: SacButton.primary(
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
              ),
            ),
        ],
      ),
    );

    final tappable = showHistory && !showSubmit
        ? SacPressable(
            onTap: onHistoryTap,
            semanticLabel: '$title. ${'investiture.history.open_action'.tr()}',
            child: card,
          )
        : card;

    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 2),
      child: tappable,
    );
  }

  String _title({required bool canSubmit}) {
    if (status == InvestitureStatus.rejected) return 'Observada';
    if (canSubmit) return 'Lista para enviar';
    return status.label;
  }

  String? _subtitle({
    required bool canSubmit,
    required bool canCurrentUserSubmit,
    required bool isContextLoading,
    required bool hasContextError,
  }) {
    if (canSubmit) {
      if (canCurrentUserSubmit) {
        return status == InvestitureStatus.rejected
            ? 'Revisa el historial antes de reenviar.'
            : 'Todos los requisitos están validados.';
      }
      if (isContextLoading) return 'Preparando el contexto del club…';
      if (hasContextError) {
        return 'No pudimos confirmar tu rol activo. Cambia de sección o recarga.';
      }
      return status == InvestitureStatus.rejected
          ? 'Un consejero o director debe reenviarla.'
          : 'Un consejero o director debe enviarla.';
    }
    if (status == InvestitureStatus.investido) return null;
    return 'investiture.history.estimated_time'.tr();
  }
}

class _InvestitureStatusRow extends StatelessWidget {
  final _InvestitureCardStyle style;
  final String title;
  final String? subtitle;
  final bool showChevron;
  final VoidCallback? onTap;

  const _InvestitureStatusRow({
    required this.style,
    required this.title,
    this.subtitle,
    this.showChevron = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: c.paper.withValues(alpha: 0.78),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: HugeIcon(
                  icon: style.icon,
                  size: 18,
                  color: style.foreground,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: c.ink900,
                      height: 1.15,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: c.ink600,
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (showChevron) ...[
              const SizedBox(width: 8),
              HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                size: 18,
                color: style.foreground.withValues(alpha: 0.7),
              ),
            ],
          ],
        ),
      ),
    );

    if (onTap == null) return row;

    return SacPressable(
      onTap: onTap,
      semanticLabel: '$title. ${'investiture.history.open_action'.tr()}',
      child: row,
    );
  }
}

class _InvestitureCardStyle {
  final Color background;
  final Color border;
  final Color foreground;
  final dynamic icon;

  const _InvestitureCardStyle({
    required this.background,
    required this.border,
    required this.foreground,
    required this.icon,
  });

  factory _InvestitureCardStyle.forStatus(InvestitureStatus status) {
    switch (status) {
      case InvestitureStatus.rejected:
        return _InvestitureCardStyle(
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
          background: AppColors.sentBg,
          border: AppColors.sentColor.withValues(alpha: 0.22),
          foreground: AppColors.sentDark,
          icon: HugeIcons.strokeRoundedClock01,
        );
      case InvestitureStatus.investido:
        return _InvestitureCardStyle(
          background: AppColors.validatedBg,
          border: AppColors.validatedColor.withValues(alpha: 0.22),
          foreground: AppColors.validatedDark,
          icon: HugeIcons.strokeRoundedCheckmarkCircle02,
        );
      case InvestitureStatus.inProgress:
      case InvestitureStatus.expired:
        return _InvestitureCardStyle(
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.error.withValues(alpha: 0.2)
            : const Color(0xFFFFF1F2),
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

class _PrerequisitesBanner extends StatelessWidget {
  final List<ClassPrerequisite> prerequisites;

  const _PrerequisitesBanner({required this.prerequisites});

  @override
  Widget build(BuildContext context) {
    final names = prerequisites.map((p) => p.name).join(', ');

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.sentBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.sentColor.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedInformationCircle,
            size: 18,
            color: AppColors.sentDark,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.sentDark,
                  height: 1.4,
                ),
                children: [
                  const TextSpan(text: 'Requiere: '),
                  TextSpan(
                    text: names,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── HeroCard ───────────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  final ClassWithProgress classData;
  final Color classColor;

  const _HeroCard({
    required this.classData,
    required this.classColor,
  });

  @override
  Widget build(BuildContext context) {
    final pct = classData.investitureProgressPercent;
    final showAdvancedSection = classData.hasAdvancedTrackData;
    final hasTrackData = classData.hasTrackData;
    final validated = classData.completedRequirements;
    final total = classData.totalRequirements;
    final c = context.sac;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: c.paper,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: classColor.withValues(alpha: 0.18)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
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
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: c.ink400,
                        letterSpacing: 0.88,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Big percentage — cuenta hacia el nuevo valor al validar
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        AnimatedCounter(
                          value: pct,
                          duration: const Duration(milliseconds: 700),
                          style: TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.w800,
                            color: classColor,
                            height: 1,
                            letterSpacing: -1.3,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        Text(
                          '%',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: classColor,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                    if (hasTrackData) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Desarrollo + actividades complementarias',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: c.ink500,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ] else if (!hasTrackData) ...[
                      const SizedBox(height: 10),
                      // Sub text (legacy)
                      RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 13,
                            color: c.ink500,
                          ),
                          children: [
                            TextSpan(
                              text: '$validated',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: c.ink800,
                              ),
                            ),
                            TextSpan(text: ' de $total requisitos validados'),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 16),

              // Right: class identity + 56×56 donut
              Stack(
                alignment: Alignment.center,
                children: [
                  HeroDonut(
                    progress: classData.investitureProgressRatio,
                    color: classColor,
                  ),
                  ClassIdentityBadge(
                    className: classData.name,
                    imageUrl: classData.imageUrl,
                    size: 34,
                    logoPadding: 5,
                    borderRadius: 11,
                    fallbackIcon: HugeIcons.strokeRoundedBookOpen01,
                  ),
                ],
              ),
            ],
          ),
          if (showAdvancedSection) ...[
            const SizedBox(height: 16),
            _AdvancedTrackSection(classData: classData),
          ],
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
      height: 30,
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
          const SizedBox(width: 5),
          _StatusPill(
            color: AppColors.sentColor,
            bg: AppColors.sentBg,
            label: 'Enviados',
            count: sent,
          ),
          const SizedBox(width: 5),
          _StatusPill(
            color: AppColors.observedColor,
            bg: AppColors.observedBg,
            label: 'Observados',
            count: observed,
          ),
          const SizedBox(width: 5),
          _StatusPill(
            color: AppColors.rejectedColor,
            bg: AppColors.rejectedBg,
            label: 'Rechazados',
            count: rejected,
          ),
          const SizedBox(width: 5),
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
    final c = context.sac;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: c.ink800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: c.ink600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Advanced track summary ─────────────────────────────────────────────────────

class _AdvancedTrackSection extends StatelessWidget {
  final ClassWithProgress classData;

  const _AdvancedTrackSection({
    required this.classData,
  });

  int get _percentage =>
      (classData.advancedProgress?.percentage ?? 0).clamp(0, 100).toInt();

  String get _status {
    if (_percentage >= 100) return 'Completa';
    if (_percentage > 0) return 'En curso';
    return 'Pendiente';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Semantics(
      label:
          'Sección avanzada: $_percentage por ciento. Avance independiente de investidura.',
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 68),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: c.canvas,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.ink150),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    'Sección avanzada',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: c.ink800,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                AnimatedCounter(
                  value: _percentage,
                  suffix: '%',
                  duration: const Duration(milliseconds: 500),
                  style: TextStyle(
                    fontSize: 16,
                    color: c.ink900,
                    fontWeight: FontWeight.w800,
                    height: 1,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '$_status · avance independiente',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: c.ink500,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 9),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: _percentage / 100),
                duration: SacMotion.reduceMotionOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 600),
                curve: SacMotion.easeOut,
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: 2,
                  backgroundColor: c.ink150,
                  color: AppColors.sentColor.withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── SearchBar ──────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final Color accentColor;
  final bool isFocused;
  final bool hasQuery;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.accentColor,
    required this.isFocused,
    required this.hasQuery,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: SacMotion.easeOut,
      margin: const EdgeInsets.only(top: 12, bottom: 18),
      decoration: BoxDecoration(
        color: c.paper,
        borderRadius: BorderRadius.circular(isFocused ? 14 : 12),
        border: Border.all(
          color: isFocused ? accentColor : c.ink150,
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          HugeIcon(
            icon: HugeIcons.strokeRoundedSearch01,
            size: 16,
            color: isFocused ? accentColor : c.ink400,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              style: TextStyle(
                fontSize: 13.5,
                color: c.ink800,
              ),
              decoration: InputDecoration(
                hintText: 'Buscar requerimiento o módulo…',
                hintStyle: TextStyle(
                  fontSize: 13.5,
                  color: c.ink400,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
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
                  color: c.ink400,
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
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: context.sac.ink400,
          letterSpacing: 1.32,
        ),
      ),
    );
  }
}

// ── Requirement track sections ────────────────────────────────────────────────

class _RequirementTrackSections extends StatelessWidget {
  final int classId;
  final _RequirementTrackBuckets buckets;
  final void Function(ClassRequirement) onRequirementTap;

  const _RequirementTrackSections({
    required this.classId,
    required this.buckets,
    required this.onRequirementTap,
  });

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];

    if (buckets.basicModules.isNotEmpty) {
      children.addAll([
        const _SectionLabel(text: 'DESARROLLO DE CLASE'),
        _ModulesCard(
          classId: classId,
          modules: buckets.basicModules,
          onRequirementTap: onRequirementTap,
        ),
      ]);
    }

    if (buckets.advancedRequirements.isNotEmpty) {
      if (children.isNotEmpty) children.add(const SizedBox(height: 18));
      children.addAll([
        const _SectionLabel(text: 'AVANZADO'),
        _RequirementListCard(
          requirements: buckets.advancedRequirements,
          onRequirementTap: onRequirementTap,
        ),
      ]);
    }

    if (buckets.extraRequirements.isNotEmpty) {
      if (children.isNotEmpty) children.add(const SizedBox(height: 18));
      children.addAll([
        const _SectionLabel(text: 'ACTIVIDADES COMPLEMENTARIAS'),
        _RequirementListCard(
          requirements: buckets.extraRequirements,
          onRequirementTap: onRequirementTap,
        ),
      ]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}

// ── Modules card ───────────────────────────────────────────────────────────────

class _ModulesCard extends ConsumerWidget {
  final int classId;
  final List<ClassModuleDetail> modules;
  final void Function(ClassRequirement) onRequirementTap;

  const _ModulesCard({
    required this.classId,
    required this.modules,
    required this.onRequirementTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final honors = ref.watch(classHonorsProvider(classId)).valueOrNull ??
        const <ClassHonor>[];
    final firstPendingModuleIndex = modules.indexWhere(
      (module) =>
          module.requirements.isNotEmpty &&
          module.completedCount < module.requirements.length,
    );

    final c = context.sac;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: c.paper,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.ink150),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < modules.length; i++) ...[
              if (i > 0)
                Divider(
                  color: c.ink100,
                  height: 1,
                  thickness: 1,
                ),
              ModuleDetailRow(
                module: modules[i],
                honors: honors
                    .where((honor) => honor.moduleId == modules[i].id)
                    .toList(),
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

// ── Requirement list card ─────────────────────────────────────────────────────

class _RequirementListCard extends StatelessWidget {
  final List<ClassRequirement> requirements;
  final void Function(ClassRequirement) onRequirementTap;

  const _RequirementListCard({
    required this.requirements,
    required this.onRequirementTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: c.paper,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.ink150),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final requirement in requirements)
              RequirementCard(
                requirement: requirement,
                onTap: () => onRequirementTap(requirement),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Especialidades recomendadas ─────────────────────────────────────────────────

class _RecommendedHonorsSection extends ConsumerWidget {
  final int classId;

  const _RecommendedHonorsSection({required this.classId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final honorsAsync = ref.watch(classHonorsProvider(classId));

    return honorsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (honors) {
        final suggestedHonors = ClassHonor.forClassCarousel(honors);
        if (suggestedHonors.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 0, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(right: 16),
                child: _SectionLabel(text: 'ESPECIALIDADES RECOMENDADAS'),
              ),
              SizedBox(
                height: 148,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  padding: const EdgeInsets.only(right: 16),
                  itemCount: suggestedHonors.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final honor = suggestedHonors[index];
                    return _HonorCard(
                      honor: honor,
                      onTap: () => context.push(
                        RouteNames.honorDetailPath(honor.honorId.toString()),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HonorCard extends StatelessWidget {
  final ClassHonor honor;
  final VoidCallback onTap;

  const _HonorCard({required this.honor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final badgeStyle = _honorRelationBadgeStyle(honor.relationType);
    final c = context.sac;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 118,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: c.paper,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.ink150),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: double.infinity,
                    height: 64,
                    child: Container(
                      color: c.canvas,
                      child: honor.honorImage != null
                          ? SacNetworkImage(
                              imageUrl: honor.honorImage!,
                              fit: BoxFit.contain,
                              errorWidget: (_, __, ___) => Center(
                                child: HugeIcon(
                                  icon: HugeIcons.strokeRoundedStar,
                                  size: 24,
                                  color: c.ink300,
                                ),
                              ),
                            )
                          : Center(
                              child: HugeIcon(
                                icon: HugeIcons.strokeRoundedStar,
                                size: 24,
                                color: c.ink300,
                              ),
                            ),
                    ),
                  ),
                ),
                if (honor.isCompletedByUser)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: AppColors.validatedColor,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedTick02,
                          size: 13,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              honor.honorName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: c.ink800,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: badgeStyle.background,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                honor.relationType.label,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: badgeStyle.foreground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HonorBadgeStyle {
  final Color background;
  final Color foreground;

  const _HonorBadgeStyle({required this.background, required this.foreground});
}

_HonorBadgeStyle _honorRelationBadgeStyle(ClassHonorRelationType type) {
  switch (type) {
    case ClassHonorRelationType.required:
      return const _HonorBadgeStyle(
        background: AppColors.rejectedBg,
        foreground: AppColors.rejectedDark,
      );
    case ClassHonorRelationType.elective:
      return const _HonorBadgeStyle(
        background: AppColors.sentBg,
        foreground: AppColors.sentDark,
      );
    case ClassHonorRelationType.recommended:
      return const _HonorBadgeStyle(
        background: AppColors.validatedBg,
        foreground: AppColors.validatedDark,
      );
  }
}

// ── No results card ────────────────────────────────────────────────────────────

class _NoResultsCard extends StatelessWidget {
  final String query;
  final List<String> suggestions;
  final Color accentColor;
  final void Function(String) onSuggestionTap;

  const _NoResultsCard({
    required this.query,
    required this.suggestions,
    required this.accentColor,
    required this.onSuggestionTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: c.paper,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.ink150),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Illustration circle
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: c.canvas,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: RepaintBoundary(
                child: CustomPaint(
                  size: const Size(64, 64),
                  painter: _SearchIllustrationPainter(
                    accentColor,
                    lensColor: c.ink200,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Title
          Text(
            'No encontramos coincidencias',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: c.ink900,
            ),
          ),

          const SizedBox(height: 6),

          // Subtitle
          SizedBox(
            width: 260,
            child: Text(
              'Prueba con otras palabras o revisa los módulos uno por uno desde la lista completa.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: c.ink500,
                height: 1.45,
              ),
            ),
          ),

          const SizedBox(height: 22),

          // Suggestions section
          if (suggestions.isNotEmpty) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'SUGERENCIAS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: c.ink400,
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
                        color: accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Text(
                        term,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: accentColor,
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
  final Color accentColor;
  final Color lensColor;

  const _SearchIllustrationPainter(this.accentColor, {required this.lensColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.44, size.height * 0.44);
    const outerRadius = 18.0;
    const innerRadius = 12.0;
    const strokeWidth = 3.0;

    // Outer circle (lens)
    final outerPaint = Paint()
      ..color = lensColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, outerRadius, outerPaint);

    // Inner fill
    final innerFill = Paint()
      ..color = accentColor.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, innerRadius, innerFill);

    // Handle
    final handlePaint = Paint()
      ..color = lensColor
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
      text: TextSpan(
        text: '?',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: accentColor,
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
  bool shouldRepaint(covariant _SearchIllustrationPainter oldDelegate) =>
      oldDelegate.accentColor != accentColor ||
      oldDelegate.lensColor != lensColor;
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
        color: context.sac.ink100,
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
    final c = context.sac;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedSchool,
            size: 48,
            color: c.ink400,
          ),
          const SizedBox(height: 12),
          Text(
            'classes.detail_with_progress.empty_modules_title'.tr(),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: c.ink500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'classes.detail_with_progress.empty_modules_body'.tr(),
            style: TextStyle(
              fontSize: 13,
              color: c.ink400,
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
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: context.sac.ink900,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(fontSize: 13, color: context.sac.ink500),
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
