import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sacdia_app/core/errors/user_error_message.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';

import '../../domain/entities/role_candidate.dart';
import '../providers/role_candidates_providers.dart';
import '../utils/role_candidate_labels.dart';
import 'role_candidate_header.dart';

/// Detail of a candidate (role history, certifications, insurance, honors).
/// Never shows email or phone: the endpoint does not publish them.
class RoleCandidateDetailStep extends ConsumerWidget {
  const RoleCandidateDetailStep({
    super.key,
    required this.query,
    required this.candidate,
  });

  final RoleCandidateDetailQuery query;

  /// Already-loaded row, shown while the detail loads.
  final RoleCandidate candidate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(roleCandidateDetailProvider(query));
    return async.when(
      loading: () => ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          RoleCandidateHeader(candidate: candidate),
          const SizedBox(height: 32),
          const Center(child: SacLoading()),
        ],
      ),
      error: (error, _) => SacErrorState(
        title: 'members.role_candidates.detail_error'.tr(),
        message: userErrorMessage(error),
        onRetry: () => ref.invalidate(roleCandidateDetailProvider(query)),
      ),
      data: (detail) => _DetailBody(detail: detail),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.detail});

  final RoleCandidateDetail detail;

  @override
  Widget build(BuildContext context) {
    final candidate = detail.candidate;
    final locale = context.locale.toString();
    String date(DateTime d) => DateFormat.yMMMd(locale).format(d.toLocal());

    final insurance = detail.insurance;
    // No records: shown as the section's muted empty note, like the others.
    final insuranceText = insurance == null
        ? null
        : insurance.active
            ? (insurance.expiresAt == null
                ? 'members.role_candidates.insurance_active'.tr()
                : tr('members.role_candidates.insurance_active_until',
                    namedArgs: {'date': date(insurance.expiresAt!)}))
            : 'members.role_candidates.insurance_inactive'.tr();

    final credential = detail.counselorCredential;
    final credentialSubtitle = credential == null
        ? ''
        : [
            if (credential.completedAt != null) date(credential.completedAt!),
          ].join(' · ');

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        RoleCandidateHeader(candidate: candidate),
        const SizedBox(height: 20),
        _Section(
          title: 'members.role_candidates.detail_history'.tr(),
          emptyText: 'members.role_candidates.detail_history_empty'.tr(),
          lines: [
            for (final h in detail.roleHistory)
              _Line(
                title: candidateRoleLabel(h.role, gender: candidate.gender),
                subtitle: [
                  if (h.clubTypeName != null) h.clubTypeName!,
                  if (h.yearName != null) h.yearName!,
                ].join(' · '),
              ),
          ],
        ),
        const SizedBox(height: 20),
        _Section(
          key: const ValueKey('credential-section'),
          title: 'members.role_candidates.credential.title'.tr(),
          note: requirementSeverityNote(detail.requirementSeverity),
          emptyText: 'members.role_candidates.credential.status_none'.tr(),
          lines: [
            if (credential != null)
              _Line(
                title: credentialStatusLabel(credential.status),
                subtitle: credentialSubtitle,
              ),
          ],
        ),
        const SizedBox(height: 20),
        _Section(
          title: 'members.role_candidates.detail_certifications'.tr(),
          note: 'members.role_candidates.detail_cert_note'.tr(),
          emptyText: 'members.role_candidates.detail_certifications_empty'.tr(),
          lines: [
            for (final cert in detail.certifications)
              _Line(
                title: cert.name,
                subtitle: [
                  if (cert.status != null) _certStatusLabel(cert.status!),
                  if (cert.certifiedAt != null) date(cert.certifiedAt!),
                ].join(' · '),
              ),
          ],
        ),
        const SizedBox(height: 20),
        _Section(
          title: 'members.role_candidates.detail_insurance'.tr(),
          emptyText: 'members.role_candidates.insurance_unknown'.tr(),
          lines: [
            if (insuranceText != null) _Line(title: insuranceText),
          ],
        ),
        const SizedBox(height: 20),
        _Section(
          title: 'members.role_candidates.detail_honors'.tr(),
          emptyText: 'members.role_candidates.honors_none'.tr(),
          lines: [
            if (detail.honorsCount > 0)
              _Line(
                title: 'members.role_candidates.honors_count'
                    .plural(detail.honorsCount),
              ),
          ],
        ),
      ],
    );
  }
}

/// Known statuses are translated; anything else is shown as the server sent it.
String _certStatusLabel(String status) {
  final key = 'members.role_candidates.cert_status.${status.toLowerCase()}';
  final translated = key.tr();
  return translated == key ? status : translated;
}

class _Line {
  const _Line({required this.title, this.subtitle = ''});

  final String title;
  final String subtitle;
}

class _Section extends StatelessWidget {
  const _Section({
    super.key,
    required this.title,
    required this.lines,
    this.note,
    this.emptyText,
  });

  final String title;
  final List<_Line> lines;
  final String? note;
  final String? emptyText;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: TextStyle(
                fontSize: SacFontSize.titleSmall,
                fontWeight: FontWeight.w700,
                color: c.textSecondary,
              ),
            ),
          ),
        ),
        if (note != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(
              note!,
              style: TextStyle(
                fontSize: SacFontSize.bodySmall,
                color: c.textSecondary,
                height: 1.3,
              ),
            ),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            border: Border.all(color: c.border),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            child: Column(
              children: lines.isEmpty
                  ? [
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text(
                          emptyText ?? '',
                          style: TextStyle(
                            fontSize: SacFontSize.bodyMedium,
                            color: c.textSecondary,
                          ),
                        ),
                      ),
                    ]
                  : [
                      for (var i = 0; i < lines.length; i++) ...[
                        if (i > 0) Divider(height: 1, color: c.borderLight),
                        _LineTile(line: lines[i]),
                      ],
                    ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LineTile extends StatelessWidget {
  const _LineTile({required this.line});

  final _Line line;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              line.title,
              style: TextStyle(
                fontSize: SacFontSize.titleSmall,
                fontWeight: FontWeight.w600,
                color: c.text,
              ),
            ),
            if (line.subtitle.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                line.subtitle,
                style: TextStyle(
                  fontSize: SacFontSize.bodySmall,
                  color: c.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
