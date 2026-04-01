import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/staggered_list_animation.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/features/certifications/domain/entities/certification_detail.dart';
import 'package:sacdia_app/features/certifications/domain/entities/certification_module.dart';

import '../providers/certifications_providers.dart';
import 'certification_progress_view.dart';

/// Vista de detalle de certificación.
///
/// Muestra nombre, descripción, árbol de módulos → secciones.
/// Si el usuario está inscrito: indicadores de progreso por módulo y botón
/// para navegar a la vista de progreso detallada.
/// Si no está inscrito: CTA de inscripción.
class CertificationDetailView extends ConsumerWidget {
  final int certificationId;

  const CertificationDetailView({
    super.key,
    required this.certificationId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(certificationDetailProvider(certificationId));

    return Scaffold(
      backgroundColor: context.sac.background,
      body: detailAsync.when(
        loading: () => const Center(child: SacLoading()),
        error: (error, _) => _ErrorBody(
          message: error.toString().replaceFirst('Exception: ', ''),
          onRetry: () =>
              ref.invalidate(certificationDetailProvider(certificationId)),
        ),
        data: (detail) => _DetailBody(
          detail: detail,
          certificationId: certificationId,
        ),
      ),
    );
  }
}

// ── Detail Body ───────────────────────────────────────────────────────────────

class _DetailBody extends ConsumerWidget {
  final CertificationDetail detail;
  final int certificationId;

  const _DetailBody({
    required this.detail,
    required this.certificationId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userCertificationsAsync = ref.watch(userCertificationsProvider);
    final c = context.sac;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        // Hero header
        SliverAppBar(
          expandedHeight: 200,
          pinned: true,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primary, AppColors.primaryDark],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: HugeIcon(
                            icon: HugeIcons.strokeRoundedCertificate01,
                            size: 30,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        detail.name,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // Body content
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Descripción
                if (detail.description != null &&
                    detail.description!.isNotEmpty) ...[
                  _SectionTitle(
                    icon: HugeIcons.strokeRoundedInformationCircle,
                    label: 'Descripción',
                  ),
                  const SizedBox(height: 10),
                  Text(
                    detail.description!,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.65,
                      color: c.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Stats row
                _StatsRow(detail: detail),
                const SizedBox(height: 24),

                // CTA según estado de inscripción
                userCertificationsAsync.when(
                  data: (userCertifications) {
                    final enrollment = userCertifications
                        .where((uc) => uc.certificationId == certificationId)
                        .firstOrNull;
                    final isEnrolled = enrollment != null;

                    if (isEnrolled) {
                      return _EnrolledCTA(
                        enrollmentId: enrollment.enrollmentId,
                        certificationId: certificationId,
                        progressPercentage: enrollment.progressPercentage,
                      );
                    }
                    return _NotEnrolledCTA(certificationId: certificationId);
                  },
                  loading: () => const SacLoading(),
                  error: (_, __) =>
                      _NotEnrolledCTA(certificationId: certificationId),
                ),

                const SizedBox(height: 28),
                Divider(color: c.border),
                const SizedBox(height: 20),

                // Árbol de módulos y secciones
                _SectionTitle(
                  icon: HugeIcons.strokeRoundedCheckList,
                  label: 'Módulos y Secciones',
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),

        // Módulos
        if (detail.modules.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              child: Center(
                child: Text(
                  'No hay módulos disponibles para esta certificación.',
                  style: TextStyle(
                    fontSize: 14,
                    color: context.sac.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final module = detail.modules[index];
                return StaggeredListItem(
                  index: index,
                  child: _ModuleTreeCard(module: module),
                );
              },
              childCount: detail.modules.length,
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }
}

// ── Stats Row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final CertificationDetail detail;

  const _StatsRow({required this.detail});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final totalSections = detail.modules.fold<int>(
      0,
      (sum, m) => sum + m.sections.length,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          _StatItem(
            icon: HugeIcons.strokeRoundedCheckList,
            value: '${detail.modulesCount}',
            label: 'Módulos',
          ),
          Container(
            width: 1,
            height: 36,
            color: c.border,
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),
          _StatItem(
            icon: HugeIcons.strokeRoundedTaskDone01,
            value: '$totalSections',
            label: 'Secciones',
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final HugeIconData icon;
  final String value;
  final String label;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Expanded(
      child: Row(
        children: [
          HugeIcon(icon: icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: c.text,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: c.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Enrolled CTA ──────────────────────────────────────────────────────────────

class _EnrolledCTA extends StatelessWidget {
  final int enrollmentId;
  final int certificationId;
  final double progressPercentage;

  const _EnrolledCTA({
    required this.enrollmentId,
    required this.certificationId,
    required this.progressPercentage,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Badge inscrito + progreso
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.secondaryLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.secondary.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedCheckmarkCircle01,
                size: 24,
                color: AppColors.secondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Estás inscrito',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.secondaryDark,
                      ),
                    ),
                    Text(
                      'Progreso: ${progressPercentage.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.secondaryDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SacButton.primary(
          text: 'Ver mi progreso',
          icon: HugeIcons.strokeRoundedAnalytics01,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CertificationProgressView(
                  enrollmentId: enrollmentId,
                  certificationId: certificationId,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ── Not Enrolled CTA ──────────────────────────────────────────────────────────

class _NotEnrolledCTA extends ConsumerWidget {
  final int certificationId;

  const _NotEnrolledCTA({required this.certificationId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SacButton.primary(
      text: 'Inscribirme en esta certificación',
      icon: HugeIcons.strokeRoundedAdd01,
      onPressed: () => _enroll(context, ref),
    );
  }

  Future<void> _enroll(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Inscribirse'),
        content: const Text(
          '¿Confirmar inscripción en esta certificación?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref
          .read(certificationEnrollmentNotifierProvider(certificationId).notifier)
          .enroll();
      ref.invalidate(userCertificationsProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('¡Inscripción exitosa!'),
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

// ── Module Tree Card ──────────────────────────────────────────────────────────

class _ModuleTreeCard extends StatefulWidget {
  final CertificationModule module;

  const _ModuleTreeCard({required this.module});

  @override
  State<_ModuleTreeCard> createState() => _ModuleTreeCardState();
}

class _ModuleTreeCardState extends State<_ModuleTreeCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header del módulo
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: c.surfaceVariant,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        '${widget.module.sections.length}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.module.name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: c.text,
                          ),
                    ),
                  ),
                  HugeIcon(
                    icon: _expanded
                        ? HugeIcons.strokeRoundedArrowUp01
                        : HugeIcons.strokeRoundedArrowDown01,
                    size: 16,
                    color: c.textTertiary,
                  ),
                ],
              ),
            ),
          ),

          // Secciones expandibles
          if (_expanded) ...[
            if (widget.module.sections.isEmpty)
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  'No hay secciones en este módulo.',
                  style: TextStyle(fontSize: 13, color: c.textSecondary),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                child: Column(
                  children: widget.module.sections.map((section) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedCircle,
                            size: 8,
                            color: c.textTertiary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              section.name,
                              style: TextStyle(
                                fontSize: 13,
                                color: c.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ── Section Title ─────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final HugeIconData icon;
  final String label;

  const _SectionTitle({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        HugeIcon(icon: icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: context.sac.text,
              ),
        ),
      ],
    );
  }
}

// ── Error Body ────────────────────────────────────────────────────────────────

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
              size: 56,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Error al cargar la certificación',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: context.sac.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SacButton.primary(
              text: 'Reintentar',
              icon: HugeIcons.strokeRoundedRefresh,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
