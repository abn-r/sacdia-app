import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/animations/staggered_list_animation.dart';
import '../../../../core/config/route_names.dart';
import '../../../../core/errors/user_error_message.dart';
import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/evidence_staging/evidence_footer_bar.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_empty_state.dart';
import '../../../../core/widgets/sac_error_state.dart';
import '../../../../core/widgets/sac_pressable.dart';
import '../../../../core/widgets/sac_snack_bar.dart';
import '../../../../core/widgets/sac_top_bar.dart';
import '../../../classes/presentation/widgets/grouped_class_skeleton.dart';
import '../../domain/entities/certification_detail.dart';
import '../../domain/entities/certification_eligibility.dart';
import '../../domain/entities/certification_progress.dart';
import '../../domain/entities/certification_status.dart';
import '../providers/certifications_providers.dart';
import '../utils/certification_status_view.dart';
import '../widgets/certification_eligibility_section.dart';
import '../widgets/certification_header.dart';
import '../widgets/certification_sections.dart';
import '../widgets/certification_sheets.dart';
import '../widgets/certification_summary_box.dart';

/// A certification, enrolled or not. It is the class screen for a
/// certification: header with icon, name and status; one summary box
/// («Requisitos validados · 6 de 19 · faltan 13»); what needs attention; the
/// modules as rows; and «Cierre» at the end.
///
/// Before enrolling it is the same screen with «Disponible», the description
/// in three lines, what the certification asks, its modules (read-only) and
/// one fixed action, «Inscribirme».
///
/// Route: `/certification/:certificationId`.
class CertificationView extends ConsumerWidget {
  const CertificationView({super.key, required this.certificationId});

  final int certificationId;

  void _refresh(WidgetRef ref) {
    ref.invalidate(userCertificationsProvider);
    ref.invalidate(certificationProgressProvider(certificationId));
    ref.invalidate(certificationDetailProvider(certificationId));
    ref.invalidate(certificationEligibilityProvider(certificationId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final enrollmentsAsync = ref.watch(userCertificationsProvider);
    final detailAsync = ref.watch(certificationDetailProvider(certificationId));
    final enrollment = activeEnrollmentFor(
      enrollmentsAsync.value ?? const [],
      certificationId,
    );
    final progressAsync = enrollment == null
        ? null
        : ref.watch(certificationProgressProvider(certificationId));

    ref.listen(certificationEnrollmentNotifierProvider(certificationId),
        (prev, next) {
      final message = next.errorMessage;
      if (message != null &&
          message.isNotEmpty &&
          message != prev?.errorMessage) {
        SacSnackBar.show(context, message, isError: true);
      }
    });

    final progress = progressAsync?.value;
    final detail = detailAsync.value;
    final name = progress?.certificationName ??
        detail?.name ??
        enrollment?.certificationName ??
        '';
    final isEnrolled = enrollment != null;
    final canLeave = isEnrolled && !(progress?.status.isClosed ?? false);

    Widget body;
    Widget? footer;
    if (enrollmentsAsync.value == null) {
      body = enrollmentsAsync.hasError
          ? _error(context, ref, enrollmentsAsync.error)
          : const GroupedClassSkeleton(rows: 5);
    } else if (isEnrolled) {
      if (progress == null) {
        body = progressAsync!.hasError
            ? _error(context, ref, progressAsync.error)
            : const GroupedClassSkeleton(rows: 5);
      } else {
        body = _EnrolledBody(
          progress: progress,
          certificationId: certificationId,
          onRefresh: () async => _refresh(ref),
        );
      }
    } else if (detail == null) {
      body = detailAsync.hasError
          ? _error(context, ref, detailAsync.error)
          : const GroupedClassSkeleton(rows: 5);
    } else {
      final eligibility = ref.watch(
        certificationEligibilityProvider(certificationId),
      );
      final eligible = eligibility.value?.eligible;
      body = _AvailableBody(
        detail: detail,
        eligibility: eligibility.value,
        onRefresh: () async => _refresh(ref),
      );
      footer = _EnrollFooter(
        // Unknown eligibility (loading or failed) leaves the action enabled:
        // the server refuses with CERT_ELIGIBILITY_REQUIRED when it applies.
        canEnroll: eligible != false && !eligibility.isLoading,
        isLoading: ref
            .watch(certificationEnrollmentNotifierProvider(certificationId))
            .isLoading,
        onEnroll: () => _enroll(context, ref, detail.name),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.canvas,
      appBar: SacTopBar(
        title: 'certifications.view.title'.tr(),
        backgroundColor: c.canvas,
        frosted: true,
        actions: [
          if (isEnrolled && progress != null)
            SacPressable(
              listenOnly: true,
              child: IconButton(
                key: const ValueKey('certification-menu'),
                enableFeedback: false,
                tooltip: 'nav.more_options'.tr(),
                onPressed: () => _openMenu(
                  context,
                  ref,
                  name: name,
                  description: detail?.description,
                  canLeave: canLeave,
                ),
                icon: HugeIcon(
                  icon: HugeIcons.strokeRoundedMoreHorizontal,
                  size: 20,
                  color: c.textSecondary,
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: footer,
      body: SacFrostedVeil(
        child: Builder(
          builder: (context) => SafeArea(top: false, child: body),
        ),
      ),
    );
  }

  Widget _error(BuildContext context, WidgetRef ref, Object? error) {
    return Builder(
      builder: (context) => SacErrorState(
        title: 'certifications.view.error_loading'.tr(),
        message: userErrorMessage(error ?? ''),
        padding: SacTopBar.paddingBelowBar(context, const EdgeInsets.all(32)),
        onRetry: () => _refresh(ref),
      ),
    );
  }

  Future<void> _openMenu(
    BuildContext context,
    WidgetRef ref, {
    required String name,
    required String? description,
    required bool canLeave,
  }) async {
    final action = await showCertificationMenuSheet(
      context,
      canLeave: canLeave,
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case CertificationMenuAction.about:
        await showCertificationAboutSheet(
          context,
          name: name,
          description: description,
        );
      case CertificationMenuAction.leave:
        await _leave(context, ref, name);
    }
  }

  Future<void> _enroll(BuildContext context, WidgetRef ref, String name) async {
    final confirmed = await showCertificationEnrollSheet(context, name: name);
    if (!confirmed || !context.mounted) return;
    final ok = await ref
        .read(certificationEnrollmentNotifierProvider(certificationId).notifier)
        .enroll();
    if (!ok || !context.mounted) return;
    SacSnackBar.show(
      context,
      'certifications.view.enroll_success'.tr(namedArgs: {'name': name}),
      isSuccess: true,
    );
  }

  Future<void> _leave(BuildContext context, WidgetRef ref, String name) async {
    final confirmed = await showCertificationLeaveSheet(context, name: name);
    if (!confirmed || !context.mounted) return;
    final ok = await ref
        .read(certificationEnrollmentNotifierProvider(certificationId).notifier)
        .unenroll();
    if (!ok || !context.mounted) return;
    SacSnackBar.show(
      context,
      'certifications.view.leave_success'.tr(namedArgs: {'name': name}),
      isSuccess: true,
    );
    if (context.canPop()) context.pop();
  }
}

// ── Enrolled ──────────────────────────────────────────────────────────────────

class _EnrolledBody extends StatelessWidget {
  const _EnrolledBody({
    required this.progress,
    required this.certificationId,
    required this.onRefresh,
  });

  final CertificationProgress progress;
  final int certificationId;
  final Future<void> Function() onRefresh;

  String _statusLabel() {
    final status = progress.status;
    if (status.isCertified) {
      final date = progress.certifiedAt;
      if (date != null) {
        return 'certifications.enrollment.certified_on'.tr(
          namedArgs: {'date': DateFormat('d MMM y').format(date.toLocal())},
        );
      }
    }
    return certificationStatusLabel(
      status,
      year: status.isCertified
          ? (progress.certifiedAt ?? progress.enrollmentDate).year
          : progress.enrollmentDate.year,
    );
  }

  @override
  Widget build(BuildContext context) {
    final counts = countsOfProgress(progress);
    final modules = [
      for (final m in progress.modules)
        if (m.sections.isNotEmpty) m,
    ];
    final certificateUrl = progress.certificateUrl;

    return RefreshIndicator(
      color: SacAccent.of(context).color,
      edgeOffset: SacTopBar.frostedInset(context),
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(height: SacTopBar.frostedInset(context)),
          ),
          SliverToBoxAdapter(
            child: SacEntrance(
              index: 0,
              child: CertificationHeader(
                name: progress.certificationName,
                status: _statusLabel(),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SacEntrance(
                index: 1,
                child: KeyedSubtree(
                  key: const ValueKey('certification-summary'),
                  child: CertificationSummaryBox(
                    label: 'certifications.summary.label'.tr(),
                    counts: counts,
                    percent: progressPercent(progress),
                  ),
                ),
              ),
            ),
          ),
          if (progress.status.isCertified &&
              certificateUrl != null &&
              certificateUrl.isNotEmpty)
            SliverToBoxAdapter(
              child: CertificationDownloadSection(
                onTap: () => launchUrl(
                  Uri.parse(certificateUrl),
                  mode: LaunchMode.externalApplication,
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: SacEntrance(
              index: 2,
              child: CertificationAttentionSection(
                modules: modules,
                onOpenRequirement: (s) => context.push<void>(
                  RouteNames.certificationRequirementDetailPath(
                    certificationId,
                    s.sectionId,
                    enrollmentId: progress.enrollmentId,
                  ),
                ),
              ),
            ),
          ),
          if (modules.isEmpty)
            SliverToBoxAdapter(
              child: SacEmptyState(
                title: 'certifications.view.empty_modules_title'.tr(),
                body: 'certifications.view.empty_modules_body'.tr(),
                icon: HugeIcons.strokeRoundedCertificate01,
              ),
            )
          else
            SliverToBoxAdapter(
              child: SacEntrance(
                index: 3,
                child: CertificationModulesSection(
                  modules: modules,
                  onOpenModule: (m) => context.push<void>(
                    RouteNames.certificationModulePath(
                      '$certificationId',
                      '${m.moduleId}',
                    ),
                  ),
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: SacEntrance(
              index: 4,
              child: CertificationCloseoutSection(
                status: progress.status,
                requirementsTotal: counts.total,
                onOpen: () => context.push<void>(
                  RouteNames.certificationCloseoutPath(
                    certificationId,
                    enrollmentId: progress.enrollmentId,
                    certificationName: progress.certificationName,
                  ),
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}

// ── Available ─────────────────────────────────────────────────────────────────

class _AvailableBody extends StatelessWidget {
  const _AvailableBody({
    required this.detail,
    required this.eligibility,
    required this.onRefresh,
  });

  final CertificationDetail detail;
  final CertificationEligibility? eligibility;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final description = detail.description?.trim() ?? '';
    final requirements = detail.modules.fold<int>(
      0,
      (sum, m) => sum + m.sections.length,
    );
    final modules = [
      for (final m in detail.modules)
        if (m.sections.isNotEmpty) m,
    ];
    final eligibility = this.eligibility;

    return RefreshIndicator(
      color: SacAccent.of(context).color,
      edgeOffset: SacTopBar.frostedInset(context),
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(height: SacTopBar.frostedInset(context)),
          ),
          SliverToBoxAdapter(
            child: SacEntrance(
              index: 0,
              child: CertificationHeader(
                name: detail.name,
                status: 'certifications.enrollment.available'.tr(),
              ),
            ),
          ),
          if (description.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: SacEntrance(
                  index: 1,
                  child: CertificationDescription(
                    text: description,
                    onMore: () => showCertificationAboutSheet(
                      context,
                      name: detail.name,
                      description: description,
                    ),
                  ),
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SacEntrance(
                index: 2,
                child: KeyedSubtree(
                  key: const ValueKey('certification-available-summary'),
                  child: CertificationAvailableSummary(
                    modules: modules.length,
                    requirements: requirements > 0 ? requirements : null,
                  ),
                ),
              ),
            ),
          ),
          if (eligibility != null && !eligibility.eligible)
            SliverToBoxAdapter(
              child: SacEntrance(
                index: 3,
                child: CertificationEligibilitySection(
                  eligibility: eligibility,
                ),
              ),
            ),
          if (modules.isNotEmpty)
            SliverToBoxAdapter(
              child: SacEntrance(
                index: 4,
                child: CertificationCatalogModulesSection(
                  modules: modules,
                  onOpenModule: (m) => context.push<void>(
                    RouteNames.certificationModulePath(
                      '${detail.certificationId}',
                      '${m.moduleId}',
                    ),
                  ),
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}

/// The one fixed action of an available certification.
class _EnrollFooter extends StatelessWidget {
  const _EnrollFooter({
    required this.canEnroll,
    required this.isLoading,
    required this.onEnroll,
  });

  final bool canEnroll;
  final bool isLoading;
  final VoidCallback onEnroll;

  @override
  Widget build(BuildContext context) {
    return EvidenceFooterBar(
      child: SacButton.primary(
        key: const ValueKey('certification-enroll'),
        text: 'certifications.view.enroll_cta'.tr(),
        icon: HugeIcons.strokeRoundedCertificate01,
        isEnabled: canEnroll,
        isLoading: isLoading,
        onPressed: canEnroll && !isLoading ? onEnroll : null,
      ),
    );
  }
}
