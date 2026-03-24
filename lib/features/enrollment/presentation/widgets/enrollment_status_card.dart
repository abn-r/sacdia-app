import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_loading.dart';
import '../../../members/presentation/providers/members_providers.dart';
import '../../domain/entities/enrollment.dart';
import '../providers/enrollment_providers.dart';
import '../views/enrollment_form_view.dart';

/// Card/banner que muestra el estado de inscripción anual del usuario.
///
/// - Sin inscripción activa: muestra aviso con botón para inscribirse.
/// - Con inscripción activa: muestra dirección, días de reunión y año.
///
/// Se usa en el dashboard o en la vista del club.
class EnrollmentStatusCard extends ConsumerWidget {
  const EnrollmentStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enrollmentAsync = ref.watch(currentEnrollmentProvider);
    final clubContextAsync = ref.watch(clubContextProvider);

    return enrollmentAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: SacLoading(),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (enrollment) {
        if (enrollment == null) {
          // ── No hay inscripción activa ─────────────────────────────────────
          return _PendingCard(
            onTap: () => clubContextAsync.whenData(
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
            ),
          );
        }

        // ── Inscripción activa ────────────────────────────────────────────
        return _ActiveCard(enrollment: enrollment);
      },
    );
  }
}

// ── Pending card ──────────────────────────────────────────────────────────────

class _PendingCard extends StatelessWidget {
  final VoidCallback? onTap;

  const _PendingCard({this.onTap});

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
                  'Completá tu inscripción para este año',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.accentDark.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
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
      ),
    );
  }
}

// ── Active card ───────────────────────────────────────────────────────────────

class _ActiveCard extends StatelessWidget {
  final Enrollment enrollment;

  const _ActiveCard({required this.enrollment});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final days = (enrollment.meetingDays as List<String>).join(', ');

    return Container(
      decoration: BoxDecoration(
        color: AppColors.secondaryLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.4)),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                color: AppColors.secondaryDark,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Inscripto ${enrollment.year}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.secondaryDark,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.secondary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Activo',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                if (enrollment.address != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedLocation01,
                        color: AppColors.secondaryDark.withValues(alpha: 0.7),
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          enrollment.address ?? '',
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                AppColors.secondaryDark.withValues(alpha: 0.8),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                if (days.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedCalendar01,
                        color: AppColors.secondaryDark.withValues(alpha: 0.7),
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          days,
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                AppColors.secondaryDark.withValues(alpha: 0.8),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
