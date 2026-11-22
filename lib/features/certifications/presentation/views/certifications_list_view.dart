import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/animations/staggered_list_animation.dart';
import '../../../../core/config/route_names.dart';
import '../../../../core/errors/user_error_message.dart';
import '../../../../core/theme/sac_accent.dart';
import '../../../../core/widgets/sac_empty_state.dart';
import '../../../../core/widgets/sac_error_state.dart';
import '../../../../core/widgets/sac_loading.dart';
import '../../../../core/widgets/sac_top_bar.dart';
import '../../../../core/widgets/status_progress/status_progress.dart';
import '../../domain/entities/certification.dart';
import '../../domain/entities/certification_status.dart';
import '../../domain/entities/user_certification.dart';
import '../providers/certifications_providers.dart';
import '../utils/certification_status_view.dart';
import '../widgets/certification_row.dart';

/// Catalog of certifications, built like «Clases por club»: grouped lists
/// («En curso», «Disponibles», «Certificadas») with their count and each
/// certification as a row with its status on the right. Enrolling happens
/// inside the certification, not from here.
class CertificationsListView extends ConsumerWidget {
  const CertificationsListView({super.key});

  void _refresh(WidgetRef ref) {
    ref.invalidate(certificationsProvider);
    ref.invalidate(userCertificationsProvider);
    ref.invalidate(certificationsAccessProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogAsync = ref.watch(certificationsProvider);
    final enrollmentsAsync = ref.watch(userCertificationsProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: SacTopBar(title: 'certifications.list.title'.tr(), frosted: true),
      body: SacFrostedVeil(
        child: Builder(
          builder: (context) {
            final top = SacTopBar.frostedInset(context);
            final catalog = catalogAsync.value;
            if (catalog == null) {
              if (catalogAsync.hasError) {
                return Padding(
                  padding: EdgeInsets.only(top: top),
                  child: SacErrorState(
                    title: 'certifications.list.load_error'.tr(),
                    message: userErrorMessage(catalogAsync.error ?? ''),
                    onRetry: () => _refresh(ref),
                  ),
                );
              }
              return const Center(child: SacLoading());
            }
            final published = [
              for (final c in catalog)
                if (c.active) c,
            ];
            if (published.isEmpty) {
              return Padding(
                padding: EdgeInsets.only(top: top),
                child: SacEmptyState(
                  icon: HugeIcons.strokeRoundedCertificate01,
                  title: 'certifications.list.no_certifications'.tr(),
                ),
              );
            }
            if (enrollmentsAsync.value == null && enrollmentsAsync.isLoading) {
              return const Center(child: SacLoading());
            }
            return RefreshIndicator(
              color: SacAccent.of(context).color,
              edgeOffset: top,
              onRefresh: () async => _refresh(ref),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(0, top + 4, 0, 32),
                children: _groups(
                  context,
                  published,
                  enrollmentsAsync.value ?? const [],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _groups(
    BuildContext context,
    List<Certification> catalog,
    List<UserCertification> enrollments,
  ) {
    final inProgress = <(Certification, UserCertification)>[];
    final certified = <(Certification, UserCertification)>[];
    final available = <Certification>[];
    for (final c in catalog) {
      final enrollment = activeEnrollmentFor(enrollments, c.certificationId);
      if (enrollment == null) {
        available.add(c);
      } else if (enrollment.status.isCertified) {
        certified.add((c, enrollment));
      } else {
        inProgress.add((c, enrollment));
      }
    }

    void open(Certification c) => context.push(
          RouteNames.certificationDetailPath('${c.certificationId}'),
        );
    String meta(Certification c) => certificationMetaLine(
          modules: c.modulesCount,
          requirements: c.requirementsCount,
        );

    final groups = <Widget>[
      if (inProgress.isNotEmpty)
        SacGroupedSection(
          key: const ValueKey('certifications-in-progress'),
          label: 'certifications.list.section_in_progress'.tr(),
          dividerIndent: 62,
          children: [
            for (final (c, e) in inProgress)
              CertificationRow(
                key: ValueKey('certification-${c.certificationId}'),
                name: c.name,
                meta: meta(c),
                chipLabel: certificationEnrollmentLabel(e),
                chipTone: certificationChipTone(e.status),
                onTap: () => open(c),
              ),
          ],
        ),
      if (available.isNotEmpty)
        SacGroupedSection(
          key: const ValueKey('certifications-available'),
          label: 'certifications.list.section_available'.tr(),
          dividerIndent: 62,
          children: [
            for (final c in available)
              CertificationRow(
                key: ValueKey('certification-${c.certificationId}'),
                name: c.name,
                meta: meta(c),
                chipLabel: 'certifications.enrollment.available'.tr(),
                chipTone: CertificationChipTone.available,
                onTap: () => open(c),
              ),
          ],
        ),
      if (certified.isNotEmpty)
        SacGroupedSection(
          key: const ValueKey('certifications-certified'),
          label: 'certifications.list.section_certified'.tr(),
          dividerIndent: 62,
          children: [
            for (final (c, e) in certified)
              CertificationRow(
                key: ValueKey('certification-${c.certificationId}'),
                name: c.name,
                meta: meta(c),
                chipLabel: certificationEnrollmentLabel(e),
                chipTone: certificationChipTone(e.status),
                onTap: () => open(c),
              ),
          ],
        ),
    ];
    return [
      for (final (i, g) in groups.indexed) SacEntrance(index: i, child: g),
    ];
  }
}
