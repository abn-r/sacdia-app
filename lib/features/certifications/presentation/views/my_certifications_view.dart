import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:sacdia_app/core/animations/staggered_list_animation.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/responsive.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/sac_progress_bar.dart';
import 'package:sacdia_app/features/certifications/domain/entities/user_certification.dart';

import '../providers/certifications_providers.dart';
import 'certification_progress_view.dart';

/// Vista de certificaciones del usuario (inscripciones).
///
/// Muestra lista de certificaciones en las que el usuario está inscripto,
/// con barras de progreso. Permite navegar al progreso detallado y desinscribirse.
class MyCertificationsView extends ConsumerWidget {
  const MyCertificationsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userCertificationsAsync = ref.watch(userCertificationsProvider);
    final hPad = Responsive.horizontalPadding(context);
    final c = context.sac;

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: userCertificationsAsync.when(
          data: (userCertifications) {
            if (userCertifications.isEmpty) {
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
                      'No estás inscripto en ninguna certificación',
                      style: TextStyle(
                        fontSize: 16,
                        color: c.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Explorá el catálogo de certificaciones',
                      style: TextStyle(
                        fontSize: 14,
                        color: c.textTertiary,
                      ),
                    ),
                  ],
                ),
              );
            }

            // Dividir en activas y completadas
            final active = userCertifications
                .where((uc) =>
                    uc.completionStatus.toLowerCase() != 'completed' && uc.active)
                .toList();
            final completed = userCertifications
                .where((uc) =>
                    uc.completionStatus.toLowerCase() == 'completed')
                .toList();

            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async {
                ref.invalidate(userCertificationsProvider);
              },
              child: CustomScrollView(
                slivers: [
                  // Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 20),
                      child: Row(
                        children: [
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedCertificate01,
                            size: 24,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Mis Certificaciones',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Stats
                  SliverToBoxAdapter(
                    child: Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: hPad),
                      child: Row(
                        children: [
                          _StatMini(
                            value: userCertifications.length,
                            label: 'Total',
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 10),
                          _StatMini(
                            value: active.length,
                            label: 'En progreso',
                            color: AppColors.accent,
                          ),
                          const SizedBox(width: 10),
                          _StatMini(
                            value: completed.length,
                            label: 'Completadas',
                            color: AppColors.secondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 20)),

                  // Sección "En progreso"
                  if (active.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 10),
                        child: Text(
                          'En progreso',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: c.textSecondary,
                              ),
                        ),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final uc = active[index];
                          return StaggeredListItem(
                            index: index,
                            initialDelay: const Duration(milliseconds: 60),
                            staggerDelay: const Duration(milliseconds: 55),
                            child: _UserCertificationCard(
                              userCertification: uc,
                              hPad: hPad,
                              onTap: () => _navigateToProgress(context, uc),
                              onUnenroll: () => _confirmUnenroll(context, ref, uc),
                            ),
                          );
                        },
                        childCount: active.length,
                      ),
                    ),
                  ],

                  // Sección "Completadas"
                  if (completed.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 10),
                        child: Text(
                          'Completadas',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: c.textSecondary,
                              ),
                        ),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final uc = completed[index];
                          return StaggeredListItem(
                            index: active.length + index,
                            initialDelay: const Duration(milliseconds: 60),
                            staggerDelay: const Duration(milliseconds: 55),
                            child: _UserCertificationCard(
                              userCertification: uc,
                              hPad: hPad,
                              onTap: () => _navigateToProgress(context, uc),
                              onUnenroll: null, // no se desinscribe de completadas
                            ),
                          );
                        },
                        childCount: completed.length,
                      ),
                    ),
                  ],

                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
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
                    'Error al cargar mis certificaciones',
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
                      ref.invalidate(userCertificationsProvider);
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

  void _navigateToProgress(BuildContext context, UserCertification uc) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CertificationProgressView(
          enrollmentId: uc.enrollmentId,
          certificationId: uc.certificationId,
        ),
      ),
    );
  }

  Future<void> _confirmUnenroll(
    BuildContext context,
    WidgetRef ref,
    UserCertification uc,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desinscribirse'),
        content: Text(
          '¿Seguro que querés desinscribirte de "${uc.certificationName}"? Se perderá tu progreso.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Desinscribirme'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref
          .read(certificationEnrollmentNotifierProvider(uc.certificationId).notifier)
          .unenroll();
      ref.invalidate(userCertificationsProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Te desinscribiste de "${uc.certificationName}"'),
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
            content: Text(e.toString().replaceFirst('Exception: ', '')),
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

// ── User Certification Card ───────────────────────────────────────────────────

class _UserCertificationCard extends StatelessWidget {
  final UserCertification userCertification;
  final double hPad;
  final VoidCallback onTap;
  final VoidCallback? onUnenroll;

  const _UserCertificationCard({
    required this.userCertification,
    required this.hPad,
    required this.onTap,
    required this.onUnenroll,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final uc = userCertification;
    final isComplete = uc.completionStatus.toLowerCase() == 'completed';
    final progressRatio = uc.progressPercentage / 100;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.fromLTRB(hPad, 0, hPad, 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isComplete
                ? AppColors.secondary.withValues(alpha: 0.3)
                : c.border,
          ),
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
              children: [
                // Icono de estado
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isComplete
                        ? AppColors.secondaryLight
                        : AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: HugeIcon(
                    icon: isComplete
                        ? HugeIcons.strokeRoundedCheckmarkCircle01
                        : HugeIcons.strokeRoundedCertificate01,
                    size: 22,
                    color: isComplete ? AppColors.secondary : AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        uc.certificationName,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: c.text,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Inscripto el ${DateFormat('dd/MM/yyyy').format(uc.enrollmentDate)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: c.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Badge de estado
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isComplete
                        ? AppColors.secondaryLight
                        : AppColors.accentLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isComplete ? 'Completada' : 'En progreso',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isComplete
                          ? AppColors.secondaryDark
                          : AppColors.accentDark,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Barra de progreso
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Progreso',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: c.textSecondary,
                  ),
                ),
                Text(
                  '${uc.progressPercentage.toStringAsFixed(0)}% · ${uc.modulesCompleted}/${uc.modulesTotal} módulos',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isComplete ? AppColors.secondary : c.text,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SacProgressBar(
              progress: progressRatio,
              height: 7,
              color: isComplete ? AppColors.secondary : AppColors.primary,
              showShimmer: false,
            ),

            // Botón desinscribirse (solo si no está completa)
            if (onUnenroll != null) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: onUnenroll,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedCancel01,
                          size: 14,
                          color: AppColors.error,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Desinscribirme',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Stat Mini ─────────────────────────────────────────────────────────────────

class _StatMini extends StatelessWidget {
  final int value;
  final String label;
  final Color color;

  const _StatMini({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: c.textSecondary,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
