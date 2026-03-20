import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/staggered_list_animation.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/responsive.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/features/certifications/domain/entities/certification.dart';

import '../providers/certifications_providers.dart';
import 'certification_detail_view.dart';

/// Vista de lista de certificaciones (catálogo completo).
///
/// Muestra todas las certificaciones como tarjetas.
/// Si el usuario ya está inscripto, muestra un badge "Inscripto".
/// Si no está inscripto, muestra el botón "Inscribirme".
/// Solo los Guías Mayores investidos pueden inscribirse.
class CertificationsListView extends ConsumerWidget {
  const CertificationsListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final certificationsAsync = ref.watch(certificationsProvider);
    final userCertificationsAsync = ref.watch(userCertificationsProvider);
    final hPad = Responsive.horizontalPadding(context);
    final c = context.sac;

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: certificationsAsync.when(
          data: (certifications) {
            if (certifications.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedCertificate01,
                      size: 56,
                      color: c.textTertiary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No hay certificaciones disponibles',
                      style: TextStyle(
                        fontSize: 16,
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async {
                ref.invalidate(certificationsProvider);
                ref.invalidate(userCertificationsProvider);
              },
              child: ListView.builder(
                padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 24),
                itemCount: certifications.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              HugeIcon(
                                icon: HugeIcons.strokeRoundedCertificate01,
                                size: 24,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Certificaciones',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                        // Aviso de elegibilidad para Guías Mayores
                        _EligibilityBanner(),
                        const SizedBox(height: 12),
                      ],
                    );
                  }

                  final certIndex = index - 1;
                  final certification = certifications[certIndex];

                  return userCertificationsAsync.when(
                    data: (userCertifications) {
                      final isEnrolled = userCertifications.any(
                        (uc) => uc.certificationId == certification.certificationId,
                      );
                      return StaggeredListItem(
                        index: certIndex,
                        initialDelay: const Duration(milliseconds: 80),
                        staggerDelay: const Duration(milliseconds: 65),
                        child: _CertificationCard(
                          certification: certification,
                          isEnrolled: isEnrolled,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CertificationDetailView(
                                  certificationId:
                                      certification.certificationId,
                                ),
                              ),
                            );
                          },
                          onEnroll: isEnrolled
                              ? null
                              : () => _enroll(context, ref, certification),
                        ),
                      );
                    },
                    loading: () => StaggeredListItem(
                      index: certIndex,
                      child: _CertificationCard(
                        certification: certification,
                        isEnrolled: false,
                        onTap: () {},
                        onEnroll: null,
                      ),
                    ),
                    error: (_, __) => StaggeredListItem(
                      index: certIndex,
                      child: _CertificationCard(
                        certification: certification,
                        isEnrolled: false,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CertificationDetailView(
                                certificationId: certification.certificationId,
                              ),
                            ),
                          );
                        },
                        onEnroll: () =>
                            _enroll(context, ref, certification),
                      ),
                    ),
                  );
                },
              ),
            );
          },
          loading: () => const Center(child: SacLoading()),
          error: (error, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedAlert02,
                    size: 56,
                    color: AppColors.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error al cargar certificaciones',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error.toString().replaceFirst('Exception: ', ''),
                    style: TextStyle(fontSize: 14, color: c.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  SacButton.primary(
                    text: 'Reintentar',
                    icon: HugeIcons.strokeRoundedRefresh,
                    onPressed: () {
                      ref.invalidate(certificationsProvider);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _enroll(
    BuildContext context,
    WidgetRef ref,
    Certification certification,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Inscribirse'),
        content: Text(
          '¿Querés inscribirte en "${certification.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Inscribirme'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref
          .read(enrollCertificationProvider(certification.certificationId).future);
      ref.invalidate(userCertificationsProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Te inscribiste en "${certification.name}"'),
            backgroundColor: AppColors.secondary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceFirst('Exception: ', ''),
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }
}

// ── Eligibility Banner ────────────────────────────────────────────────────────

class _EligibilityBanner extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.accentLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedInformationCircle,
            size: 18,
            color: AppColors.accentDark,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Las certificaciones son exclusivas para Guías Mayores investidos.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.accentDark,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Certification Card ─────────────────────────────────────────────────────────

class _CertificationCard extends StatelessWidget {
  final Certification certification;
  final bool isEnrolled;
  final VoidCallback onTap;
  final VoidCallback? onEnroll;

  const _CertificationCard({
    required this.certification,
    required this.isEnrolled,
    required this.onTap,
    required this.onEnroll,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border),
          boxShadow: [
            BoxShadow(
              color: c.shadow,
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icono de certificación
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedCertificate01,
                    size: 22,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        certification.name,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: c.text,
                            ),
                      ),
                      if (certification.description != null &&
                          certification.description!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          certification.description!,
                          style: TextStyle(
                            fontSize: 12,
                            color: c.textSecondary,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                // Badge de inscripto
                if (isEnrolled) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Inscripto',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.secondaryDark,
                      ),
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 12),

            // Módulos count
            Row(
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedCheckList,
                  size: 14,
                  color: c.textTertiary,
                ),
                const SizedBox(width: 4),
                Text(
                  '${certification.modulesCount} módulo${certification.modulesCount != 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    color: c.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                // Botón inscribirse (solo si no está inscripto)
                if (!isEnrolled && onEnroll != null)
                  GestureDetector(
                    onTap: onEnroll,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Inscribirme',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                if (isEnrolled)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Ver progreso',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedArrowRight01,
                        size: 14,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
