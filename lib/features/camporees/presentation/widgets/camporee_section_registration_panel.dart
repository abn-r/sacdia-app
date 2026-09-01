import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee_section_registration.dart';

class CamporeeSectionRegistrationPanel extends StatelessWidget {
  final AsyncValue<CamporeeSectionRegistration> registrationAsync;
  final VoidCallback onEnroll;
  final VoidCallback onRetry;
  final VoidCallback onManageParticipants;
  final bool showActions;
  final bool showParticipantAction;

  const CamporeeSectionRegistrationPanel({
    super.key,
    required this.registrationAsync,
    required this.onEnroll,
    required this.onRetry,
    required this.onManageParticipants,
    this.showActions = true,
    this.showParticipantAction = true,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'camporees.section_registration.semantics'.tr(),
      child: SacCard(
        key: const Key('camporee-section-registration-panel'),
        padding: const EdgeInsets.all(20),
        child: registrationAsync.when(
          loading: () => Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Semantics(
                label: 'camporees.section_registration.loading'.tr(),
                liveRegion: true,
                child: const SacLoading(),
              ),
            ),
          ),
          error: (_, __) => _RegistrationError(onRetry: onRetry),
          data: (registration) => _RegistrationContent(
            registration: registration,
            onEnroll: onEnroll,
            onManageParticipants: onManageParticipants,
            showActions: showActions,
            showParticipantAction: showParticipantAction,
          ),
        ),
      ),
    );
  }
}

class _RegistrationContent extends StatelessWidget {
  final CamporeeSectionRegistration registration;
  final VoidCallback onEnroll;
  final VoidCallback onManageParticipants;
  final bool showActions;
  final bool showParticipantAction;

  const _RegistrationContent({
    required this.registration,
    required this.onEnroll,
    required this.onManageParticipants,
    required this.showActions,
    required this.showParticipantAction,
  });

  @override
  Widget build(BuildContext context) {
    final presentation = _presentationFor(context, registration);
    final colors = context.sac;
    final showDescription = _shouldShowStatusDescription(registration);
    final showEnroll = showActions &&
        registration.canEnroll &&
        registration.status == CamporeeSectionRegistrationStatus.notEnrolled;
    final showParticipants = showActions &&
        showParticipantAction &&
        registration.enablesParticipants;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'camporees.section_registration.title'.tr(),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          '${registration.clubName} · ${registration.sectionName}',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 12),
        Semantics(
          liveRegion: true,
          label: presentation.title,
          child: _StatusChip(presentation: presentation),
        ),
        if (showDescription) ...[
          const SizedBox(height: 10),
          Text(
            presentation.description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.textSecondary,
                  height: 1.45,
                ),
          ),
        ],
        if (registration.enablesParticipants &&
            registration.registeredBy != null) ...[
          const SizedBox(height: 10),
          _RegistrationMeta(registration: registration),
        ],
        if (showEnroll) ...[
          const SizedBox(height: 16),
          SacButton.primary(
            text: 'camporees.section_registration.enroll_action'.tr(),
            icon: HugeIcons.strokeRoundedEdit02,
            onPressed: onEnroll,
            backgroundColor: AppColors.primary,
            textColor: AppColors.ink900,
            labelMaxLines: 2,
            labelOverflow: TextOverflow.visible,
          ),
        ],
        if (showParticipants) ...[
          const SizedBox(height: 16),
          SacButton.primary(
            text: 'camporees.section_registration.participants_action'.tr(),
            icon: HugeIcons.strokeRoundedUserAdd01,
            onPressed: onManageParticipants,
            backgroundColor: AppColors.primary,
            textColor: AppColors.ink900,
            labelMaxLines: 2,
            labelOverflow: TextOverflow.visible,
          ),
        ],
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final _RegistrationPresentation presentation;

  const _StatusChip({required this.presentation});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: presentation.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          HugeIcon(
            icon: presentation.icon,
            color: presentation.color,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              presentation.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: presentation.color,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RegistrationMeta extends StatelessWidget {
  final CamporeeSectionRegistration registration;

  const _RegistrationMeta({required this.registration});

  @override
  Widget build(BuildContext context) {
    final actor = registration.registeredBy!;
    final date = registration.registeredAt;
    final formattedDate = date == null
        ? null
        : DateFormat.yMMMd(context.locale.toString()).format(date.toLocal());
    final label = formattedDate == null
        ? 'camporees.section_registration.registered_by'
            .tr(namedArgs: {'name': actor.displayName})
        : 'camporees.section_registration.registered_by_date'.tr(
            namedArgs: {'name': actor.displayName, 'date': formattedDate},
          );

    return Text(
      label,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: context.sac.textTertiary,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
    );
  }
}

class _RegistrationError extends StatelessWidget {
  final VoidCallback onRetry;

  const _RegistrationError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          liveRegion: true,
          child: Text(
            'camporees.section_registration.load_error'.tr(),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: context.sac.text,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'camporees.section_registration.load_error_hint'.tr(),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.sac.textSecondary,
              ),
        ),
        const SizedBox(height: 16),
        Semantics(
          label: 'camporees.section_registration.retry_semantics'.tr(),
          button: true,
          child: SacButton.outline(
            text: 'camporees.section_registration.retry'.tr(),
            icon: HugeIcons.strokeRoundedRefresh,
            onPressed: onRetry,
            textColor: context.sac.text,
            borderColor: context.sac.textSecondary,
            labelMaxLines: 2,
            labelOverflow: TextOverflow.visible,
          ),
        ),
      ],
    );
  }
}

class _RegistrationPresentation {
  final String title;
  final String description;
  final List<List<dynamic>> icon;
  final Color color;

  const _RegistrationPresentation({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}

bool _shouldShowStatusDescription(CamporeeSectionRegistration registration) {
  if (registration.enablesParticipants) return false;
  if (registration.canEnroll) return false;
  return true;
}

_RegistrationPresentation _presentationFor(
  BuildContext context,
  CamporeeSectionRegistration registration,
) {
  final colors = context.sac;
  String key;
  late List<List<dynamic>> icon;
  Color color;

  switch (registration.status) {
    case CamporeeSectionRegistrationStatus.registered:
      key = 'registered';
      icon = HugeIcons.strokeRoundedCheckmarkCircle02;
      color = colors.success;
    case CamporeeSectionRegistrationStatus.approved:
      key = 'approved';
      icon = HugeIcons.strokeRoundedCheckmarkBadge01;
      color = colors.success;
    case CamporeeSectionRegistrationStatus.pendingApproval:
      key = 'pending';
      icon = HugeIcons.strokeRoundedClock01;
      color = colors.warning;
    case CamporeeSectionRegistrationStatus.rejected:
      key = 'rejected';
      icon = HugeIcons.strokeRoundedCancelCircle;
      color = colors.error;
    case CamporeeSectionRegistrationStatus.cancelled:
      key = 'cancelled';
      icon = HugeIcons.strokeRoundedCancel01;
      color = colors.error;
    case CamporeeSectionRegistrationStatus.notEnrolled:
      if (registration.disposition ==
          CamporeeSectionRegistrationDisposition.notOpenYet) {
        key = 'not_open';
        icon = HugeIcons.strokeRoundedCalendar03;
        color = colors.info;
      } else if (registration.disposition ==
          CamporeeSectionRegistrationDisposition.manuallyFrozen) {
        key = 'frozen';
        icon = HugeIcons.strokeRoundedPause;
        color = colors.warning;
      } else if (registration.canEnroll) {
        key = registration.disposition ==
                CamporeeSectionRegistrationDisposition.lateApprovalRequired
            ? 'late_open'
            : 'open';
        icon = HugeIcons.strokeRoundedEdit02;
        color = colors.info;
      } else {
        key = 'read_only';
        icon = HugeIcons.strokeRoundedInformationCircle;
        color = colors.info;
      }
    case CamporeeSectionRegistrationStatus.unknown:
      key = 'unavailable';
      icon = HugeIcons.strokeRoundedAlert02;
      color = colors.warning;
  }

  return _RegistrationPresentation(
    title: 'camporees.section_registration.states.$key.title'.tr(),
    description: 'camporees.section_registration.states.$key.description'.tr(),
    icon: icon,
    color: color,
  );
}
