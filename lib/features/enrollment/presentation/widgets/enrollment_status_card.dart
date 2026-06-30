import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_loading.dart';
import '../../../auth/domain/utils/authorization_utils.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../members/presentation/providers/members_providers.dart';
import '../../domain/entities/enrollment.dart';
import '../providers/enrollment_providers.dart';
import '../views/enrollment_form_view.dart';

const _enrollmentCreatePermissions = {'club_instances:create'};

/// Banner de advertencia para la inscripción anual del club.
///
/// - Sin inscripción (`null`): muestra aviso con botón para completar.
/// - Con inscripción `pending_validation`/`pending`: muestra estado enviado
///   y en validación por Campo Local.
/// - Con inscripción `active`: no muestra alerta, porque el club ya está
///   aprobado para el año.
///
/// Se usa en el dashboard o en la vista del club.
class EnrollmentStatusCard extends ConsumerWidget {
  const EnrollmentStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enrollmentAsync = ref.watch(currentEnrollmentProvider);
    final clubContextAsync = ref.watch(clubContextProvider);
    final user = ref.watch(authNotifierProvider.select((v) => v.valueOrNull));
    final canEnroll = hasAnyPermission(user, _enrollmentCreatePermissions);

    return enrollmentAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(child: SacLoading()),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (enrollment) {
        // ── Inscripción enviada: espera validación de Campo Local ───────────
        if (enrollment != null &&
            (enrollment.status == EnrollmentStatus.pendingValidation ||
                enrollment.status == EnrollmentStatus.pending)) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: _SubmittedCard(),
          );
        }

        // ── Inscripción aprobada: no hay alerta pendiente ───────────────────
        if (enrollment != null &&
            enrollment.status == EnrollmentStatus.active) {
          return const SizedBox.shrink();
        }

        if (enrollment == null) {
          // ── No hay inscripción activa ─────────────────────────────────────
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _PendingCard(
              showButton: canEnroll,
              subtitle: canEnroll
                  ? 'enrollment.status.subtitle_pending_action'.tr()
                  : 'enrollment.status.subtitle_pending_viewer'.tr(),
              onTap: canEnroll
                  ? () => clubContextAsync.whenData(
                        (ctx) {
                          if (ctx == null) return;
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => EnrollmentFormView(
                                clubId: ctx.clubId.toString(),
                                sectionId: ctx.sectionId,
                              ),
                            ),
                          );
                        },
                      )
                  : null,
            ),
          );
        }

        // ── Inscripción existe pero requiere corrección / reenvío ───────────
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _PendingCard(
            showButton: canEnroll,
            subtitle: canEnroll
                ? 'enrollment.status.subtitle_inactive_action'.tr()
                : 'enrollment.status.subtitle_inactive_viewer'.tr(),
            onTap: canEnroll
                ? () => clubContextAsync.whenData(
                      (ctx) {
                        if (ctx == null) return;
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => EnrollmentFormView(
                              clubId: ctx.clubId.toString(),
                              sectionId: ctx.sectionId,
                              enrollmentId: enrollment.endpointId,
                            ),
                          ),
                        );
                      },
                    )
                : null,
          ),
        );
      },
    );
  }
}

// ── Submitted card ───────────────────────────────────────────────────────────

const double _submittedValidationScale = 0.8;
const double _submittedValidationPadding = 16 * _submittedValidationScale;
const double _submittedValidationRadius = 14 * _submittedValidationScale;
const double _submittedValidationIconBox = 40 * _submittedValidationScale;
const double _submittedValidationIconRadius = 10 * _submittedValidationScale;
const double _submittedValidationIconSize = 20 * _submittedValidationScale;
const double _submittedValidationGap = 12 * _submittedValidationScale;
const double _submittedValidationTextGap = 2 * _submittedValidationScale;
const double _submittedValidationTitleSize = 14 * _submittedValidationScale;
const double _submittedValidationSubtitleSize = 12 * _submittedValidationScale;

class _SubmittedCard extends StatelessWidget {
  const _SubmittedCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.accentLight,
        borderRadius: BorderRadius.circular(_submittedValidationRadius),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
      ),
      padding: const EdgeInsets.all(_submittedValidationPadding),
      child: Row(
        children: [
          Container(
            width: _submittedValidationIconBox,
            height: _submittedValidationIconBox,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.2),
              borderRadius:
                  BorderRadius.circular(_submittedValidationIconRadius),
            ),
            child: const Center(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                color: AppColors.accentDark,
                size: _submittedValidationIconSize,
              ),
            ),
          ),
          const SizedBox(width: _submittedValidationGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'enrollment.status.title_submitted'.tr(),
                  style: const TextStyle(
                    fontSize: _submittedValidationTitleSize,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accentDark,
                  ),
                ),
                const SizedBox(height: _submittedValidationTextGap),
                Text(
                  'enrollment.status.subtitle_submitted'.tr(),
                  style: TextStyle(
                    fontSize: _submittedValidationSubtitleSize,
                    color: AppColors.accentDark.withValues(alpha: 0.8),
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
    return Container(
      decoration: BoxDecoration(
        color: AppColors.accentLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedAlert02,
                color: AppColors.accentDark,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'enrollment.status.title_pending'.tr(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accentDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.accentDark.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          if (showButton) ...[
            const SizedBox(width: 8),
            SacButton(
              text: 'enrollment.status.button_enroll'.tr(),
              variant: SacButtonVariant.primary,
              size: SacButtonSize.small,
              onPressed: onTap,
              backgroundColor: AppColors.accent,
              textColor: Colors.white,
            ),
          ],
        ],
      ),
    );
  }
}
