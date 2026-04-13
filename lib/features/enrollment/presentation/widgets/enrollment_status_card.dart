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

/// Banner de advertencia para la inscripción anual del club.
///
/// - Sin inscripción (`null`) o con estado `pending`/`inactive`: muestra aviso
///   con botón para completar la inscripción.
/// - Con inscripción `active`: no renderiza nada (`SizedBox.shrink()`).
///
/// Se usa en el dashboard o en la vista del club.
class EnrollmentStatusCard extends ConsumerWidget {
  const EnrollmentStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enrollmentAsync = ref.watch(currentEnrollmentProvider);
    final clubContextAsync = ref.watch(clubContextProvider);
    final user = ref.watch(authNotifierProvider).valueOrNull;
    final canEnroll =
        hasAnyPermission(user, const {'enrollments:create'});

    return enrollmentAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(child: SacLoading()),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (enrollment) {
        // ── Inscripción activa: no mostrar nada ──────────────────────────────
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
                ? 'Completa la inscripción para este año'
                : 'El club aún no ha completado la inscripción para este año',
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

        // ── Inscripción existe pero no está activa (pending / inactive) ───
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _PendingCard(
            showButton: canEnroll,
            subtitle: canEnroll
                ? 'La inscripción para este año requiere atención'
                : 'La inscripción del club para este año no está activa',
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
      },
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
    this.subtitle = 'El club aún no ha completado la inscripción para este año.',
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
                  'Inscripción anual pendiente',
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
              text: 'Inscribirse',
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

