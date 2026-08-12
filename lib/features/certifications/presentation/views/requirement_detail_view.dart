import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_back_button.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_loading.dart';
import '../../domain/entities/certification_requirement.dart';
import '../../domain/entities/certification_requirement_component.dart';
import '../providers/certification_requirement_providers.dart';
import '../widgets/certification_component_field.dart';
import '../widgets/certification_requirement_status_badge.dart';

/// Vista de ejecución de un requisito (sección) de una certificación
/// configurable.
///
/// Renderiza un campo por componente según `component.type` — nunca según el
/// nombre/ID de la certificación (Task 11). Reutiliza patrones visuales de
/// `features/classes/presentation/views/requirement_detail_view.dart`
/// (banner de estado, badge, acciones) adaptados al vocabulario propio de
/// certificaciones (DRAFT/SUBMITTED/CHANGES_REQUESTED/APPROVED).
class CertificationRequirementDetailView extends ConsumerWidget {
  final int certificationId;
  final int sectionId;
  final int enrollmentId;

  const CertificationRequirementDetailView({
    super.key,
    required this.certificationId,
    required this.sectionId,
    required this.enrollmentId,
  });

  CertificationRequirementQuery get _query => CertificationRequirementQuery(
        certificationId: certificationId,
        sectionId: sectionId,
        enrollmentId: enrollmentId,
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(certificationRequirementNotifierProvider(_query));
    final c = context.sac;

    ref.listen(certificationRequirementNotifierProvider(_query), (prev, next) {
      if (next.errorMessage != null && next.errorMessage!.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        ref
            .read(certificationRequirementNotifierProvider(_query).notifier)
            .clearError();
      }
      if (next.submitSuccess && prev?.submitSuccess != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'certifications.requirement_detail.submit_success'.tr(),
            ),
            backgroundColor: AppColors.secondary,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        Navigator.of(context).pop();
      }
    });

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        surfaceTintColor: Colors.transparent,
        leading: sacAutoBackButton(context),
        title: Text(
          state.requirement?.name ??
              'certifications.requirement_detail.title'.tr(),
          style: TextStyle(fontWeight: FontWeight.w700, color: c.text),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SafeArea(
        child: state.isLoading && state.requirement == null
            ? const Center(child: SacLoading())
            : state.requirement == null
                ? _ErrorBody(
                    message: state.errorMessage ??
                        'certifications.errors.get_requirement'.tr(),
                    onRetry: () => ref
                        .read(certificationRequirementNotifierProvider(_query)
                            .notifier)
                        .reload(),
                  )
                : _RequirementBody(query: _query, state: state),
      ),
    );
  }
}

class _RequirementBody extends ConsumerWidget {
  final CertificationRequirementQuery query;
  final CertificationRequirementState state;

  const _RequirementBody({required this.query, required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requirement = state.requirement!;
    final canEdit = requirement.canEdit;
    final notifier =
        ref.read(certificationRequirementNotifierProvider(query).notifier);
    final components = state.componentsWithLocalOverlay;
    final c = context.sac;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CertificationRequirementStatusBadge(
                        status: requirement.status),
                    const Spacer(),
                    if (state.hasUnsavedLocalChanges)
                      Text(
                        'certifications.requirement_detail.unsaved_changes'
                            .tr(),
                        style: TextStyle(
                          fontSize: 11.5,
                          color: c.textTertiary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                if (requirement.status ==
                        CertificationRequirementStatus.changesRequested &&
                    (requirement.lastReviewComment?.isNotEmpty ?? false))
                  _ChangesRequestedBanner(
                      comment: requirement.lastReviewComment!),
                ..._buildReviewHistory(context, requirement),
                for (final component in components)
                  CertificationComponentField(
                    key: ValueKey(component.componentId),
                    component: component,
                    canEdit: canEdit,
                    onTextChanged: (value) => notifier.updateComponentValue(
                      CertificationComponentDraftInput(
                        componentId: component.componentId,
                        textValue: value,
                      ),
                    ),
                    onAttestationChanged: (value) =>
                        notifier.updateComponentValue(
                      CertificationComponentDraftInput(
                        componentId: component.componentId,
                        attestationConfirmed: value,
                      ),
                    ),
                    onLinkedHonorChanged: (value) =>
                        notifier.updateComponentValue(
                      CertificationComponentDraftInput(
                        componentId: component.componentId,
                        linkedUserHonorId: value,
                      ),
                    ),
                    onLinkedActivityChanged: (value) =>
                        notifier.updateComponentValue(
                      CertificationComponentDraftInput(
                        componentId: component.componentId,
                        linkedActivityId: value,
                      ),
                    ),
                    onUploadEvidence: (xFile, mimeType, onProgress) async {
                      final size = await xFile.length();
                      await notifier.uploadComponentEvidence(
                        componentId: component.componentId,
                        filePath: xFile.path,
                        fileName: xFile.name,
                        mimeType: mimeType,
                        fileSize: size,
                        onProgress: onProgress,
                      );
                    },
                    onDeleteEvidence: notifier.deleteComponentEvidence,
                  ),
              ],
            ),
          ),
        ),
        if (canEdit) _BottomActionBar(query: query, state: state),
      ],
    );
  }

  List<Widget> _buildReviewHistory(
    BuildContext context,
    CertificationRequirement requirement,
  ) {
    final events = requirement.reviewHistory;
    if (events.isEmpty) return const [];
    final c = context.sac;
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 2),
        child: Text(
          'certifications.requirement_detail.history_title'.tr(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: c.textTertiary,
            letterSpacing: 0.6,
          ),
        ),
      ),
      for (final event in events)
        Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: c.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedClock01,
                size: 16,
                color: c.textTertiary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _eventLabel(event.eventType),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: c.text,
                      ),
                    ),
                    if (event.comment != null && event.comment!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          event.comment!,
                          style: TextStyle(
                            fontSize: 12,
                            color: c.textSecondary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
    ];
  }

  String _eventLabel(String eventType) {
    switch (eventType) {
      case 'REQUIREMENT_SUBMITTED':
        return 'certifications.requirement_detail.event_submitted'.tr();
      case 'REQUIREMENT_APPROVED':
        return 'certifications.requirement_detail.event_approved'.tr();
      case 'REQUIREMENT_CHANGES_REQUESTED':
        return 'certifications.requirement_detail.event_changes_requested'.tr();
      default:
        return eventType;
    }
  }
}

class _BottomActionBar extends ConsumerWidget {
  final CertificationRequirementQuery query;
  final CertificationRequirementState state;

  const _BottomActionBar({required this.query, required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final notifier =
        ref.read(certificationRequirementNotifierProvider(query).notifier);
    final requirement = state.requirement!;
    final busy = state.isSavingDraft || state.isSubmitting;

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: SacButton.outline(
              text: 'certifications.requirement_detail.save_draft'.tr(),
              isEnabled: !busy,
              isLoading: state.isSavingDraft,
              onPressed: !busy ? () => notifier.saveDraft() : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SacButton.primary(
              text: 'certifications.requirement_detail.submit'.tr(),
              icon: HugeIcons.strokeRoundedSent,
              isEnabled: !busy && requirement.requiredComponentsComplete,
              isLoading: state.isSubmitting,
              onPressed: !busy && requirement.requiredComponentsComplete
                  ? () => notifier.submit()
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChangesRequestedBanner extends StatelessWidget {
  final String comment;

  const _ChangesRequestedBanner({required this.comment});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.observedBg,
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: AppColors.observedColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedInformationCircle,
            size: 18,
            color: AppColors.observedDark,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'certifications.requirement_detail.changes_requested_title'
                      .tr(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.observedDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  comment,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.observedDark,
                    height: 1.4,
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
              size: 48,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SacButton.primary(
              text: 'common.retry'.tr(),
              icon: HugeIcons.strokeRoundedRefresh,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
