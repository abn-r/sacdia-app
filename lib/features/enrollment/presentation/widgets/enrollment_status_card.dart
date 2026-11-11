import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_card.dart';
import '../../../../core/widgets/sac_loading.dart';
import '../../../auth/domain/utils/authorization_utils.dart';
import '../../../auth/presentation/providers/acting_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../members/presentation/providers/members_providers.dart';
import '../../domain/entities/enrollment.dart';
import '../providers/enrollment_providers.dart';
import '../views/enrollment_form_view.dart';
import 'package:sacdia_app/core/animations/page_transitions.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';

const _enrollmentCreatePermissions = {'club_instances:create'};

/// The club's annual enrollment as a task for the current user: there is no
/// enrollment yet, or it came back for correction, and the user can create
/// it. [enrollmentId] is set when the existing enrollment must be resubmitted.
class AnnualEnrollmentTask {
  const AnnualEnrollmentTask({this.enrollmentId});

  final String? enrollmentId;

  bool get isResubmit => enrollmentId != null;
}

/// The annual enrollment task, or null when there is nothing for this user to
/// do (already sent or approved, still loading, no permission, limited
/// account, or acting for a minor).
final annualEnrollmentTaskProvider =
    Provider.autoDispose<AnnualEnrollmentTask?>((ref) {
  final user = ref.watch(authNotifierProvider.select((v) => v.value));
  final acting = ref.watch(actingDependentProvider) != null;
  if (user == null || user.isLimitedAccount || acting) return null;
  if (!hasAnyPermission(user, _enrollmentCreatePermissions)) return null;

  final enrollment = ref.watch(currentEnrollmentProvider);
  if (!enrollment.hasValue) return null;
  final value = enrollment.value;
  if (value == null) return const AnnualEnrollmentTask();
  if (_isSubmitted(value) || value.status == EnrollmentStatus.active) {
    return null;
  }
  return AnnualEnrollmentTask(enrollmentId: value.endpointId);
});

bool _isSubmitted(Enrollment enrollment) =>
    enrollment.status == EnrollmentStatus.pendingValidation ||
    enrollment.status == EnrollmentStatus.pending;

/// Opens the annual enrollment form for [task] in the active club section.
void openAnnualEnrollmentForm(
  BuildContext context,
  WidgetRef ref,
  AnnualEnrollmentTask task,
) {
  final ctx = ref.read(clubContextProvider).value;
  if (ctx == null) return;
  Navigator.of(context).push(
    SacSharedAxisRoute(
      builder: (_) => EnrollmentFormView(
        clubId: ctx.clubId.toString(),
        sectionId: ctx.sectionId,
        enrollmentId: task.enrollmentId,
      ),
    ),
  );
}

/// Banner de advertencia para la inscripción anual del club.
///
/// - Sin inscripción (`null`): muestra aviso con acción para completar.
/// - Con inscripción `pending_validation`/`pending`: muestra estado enviado
///   y en validación por Campo Local.
/// - Con inscripción `active`: no muestra alerta, porque el club ya está
///   aprobado para el año.
///
/// With [showTask] false the actionable state is left out: the staff home
/// shows it as a row of «Pendientes» instead (see [annualEnrollmentTaskProvider]).
/// When shown, the card keeps [bottomSpacing] below it.
class EnrollmentStatusCard extends ConsumerWidget {
  const EnrollmentStatusCard({
    super.key,
    this.showTask = true,
    this.bottomSpacing = 16,
  });

  final bool showTask;
  final double bottomSpacing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enrollmentAsync = ref.watch(currentEnrollmentProvider);
    final user = ref.watch(authNotifierProvider.select((v) => v.value));
    final acting = ref.watch(actingDependentProvider) != null;
    // The club's yearly enrollment is staff business: a supervised teen or a
    // guardian viewing as a minor can't act on it, so the banner is noise.
    if (user == null || user.isLimitedAccount || acting) {
      return const SizedBox.shrink();
    }
    final task = ref.watch(annualEnrollmentTaskProvider);

    Widget spaced(Widget card) =>
        Padding(padding: EdgeInsets.only(bottom: bottomSpacing), child: card);

    return enrollmentAsync.when(
      // The home already has its own skeleton; a spinner here only jumps.
      loading: () => showTask
          ? Padding(
              padding: EdgeInsets.only(bottom: bottomSpacing),
              child: const Center(child: SacLoading()),
            )
          : const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (enrollment) {
        // ── Inscripción enviada: espera validación de Campo Local ───────────
        if (enrollment != null && _isSubmitted(enrollment)) {
          return spaced(const _SubmittedCard());
        }

        // ── Inscripción aprobada: no hay alerta pendiente ───────────────────
        if (enrollment != null &&
            enrollment.status == EnrollmentStatus.active) {
          return const SizedBox.shrink();
        }

        // ── Falta o requiere corrección: tarea de quien puede inscribir ─────
        if (task != null) {
          if (!showTask) return const SizedBox.shrink();
          return spaced(
            _PendingCard(
              showButton: true,
              subtitle: (task.isResubmit
                      ? 'enrollment.status.subtitle_inactive_action'
                      : 'enrollment.status.subtitle_pending_action')
                  .tr(),
              onTap: () => openAnnualEnrollmentForm(context, ref, task),
            ),
          );
        }

        // ── Sin permiso para inscribir: solo informa ────────────────────────
        return spaced(
          _PendingCard(
            subtitle: (enrollment == null
                    ? 'enrollment.status.subtitle_pending_viewer'
                    : 'enrollment.status.subtitle_inactive_viewer')
                .tr(),
          ),
        );
      },
    );
  }
}

// ── Submitted card ───────────────────────────────────────────────────────────

class _SubmittedCard extends StatelessWidget {
  const _SubmittedCard();

  @override
  Widget build(BuildContext context) {
    return _EnrollmentStatusRow(
      icon: HugeIcons.strokeRoundedCheckmarkCircle02,
      title: 'enrollment.status.title_submitted'.tr(),
      subtitle: 'enrollment.status.subtitle_submitted'.tr(),
    );
  }
}

// ── Pending card ──────────────────────────────────────────────────────────────

class _PendingCard extends StatelessWidget {
  final bool showButton;
  final String subtitle;
  final VoidCallback? onTap;

  const _PendingCard({
    this.showButton = false,
    this.subtitle =
        'El club aún no ha completado la inscripción para este año.',
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _EnrollmentStatusRow(
      icon: HugeIcons.strokeRoundedAlert02,
      title: 'enrollment.status.title_pending'.tr(),
      subtitle: subtitle,
      actionLabel: showButton ? 'enrollment.status.button_enroll'.tr() : null,
      onTap: showButton ? onTap : null,
    );
  }
}

/// Same look as the dashboard «Pendientes» card: white card, amber icon
/// well, title and subtitle. When there is an action the whole card is
/// tappable and shows a chevron.
class _EnrollmentStatusRow extends StatelessWidget {
  const _EnrollmentStatusRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onTap,
  });

  final HugeIconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final hasAction = onTap != null;

    return Semantics(
      button: hasAction,
      label:
          [title, subtitle, if (actionLabel != null) actionLabel!].join(', '),
      excludeSemantics: true,
      child: SacCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.warningContainer,
                borderRadius: BorderRadius.circular(AppTheme.radiusXS + 2),
              ),
              child: HugeIcon(
                icon: icon,
                size: 20,
                color: c.onWarningContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: SacFontSize.titleMedium,
                      fontWeight: FontWeight.w600,
                      color: c.text,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: SacFontSize.bodySmall,
                      color: c.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (hasAction) ...[
              const SizedBox(width: 8),
              HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                size: 22,
                color: c.textTertiary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
