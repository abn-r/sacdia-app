import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../../core/config/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/sla_dashboard.dart';
import '../providers/coordinator_providers.dart';

/// Hub principal de coordinación.
///
/// Muestra resumen de KPIs desde el endpoint SLA y accesos directos a cada
/// sub-módulo del coordinador: investiduras, revisión de evidencias,
/// aprobaciones de camporees y dashboard operativo.
class CoordinatorHubView extends ConsumerWidget {
  const CoordinatorHubView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slaAsync = ref.watch(slaDashboardProvider);
    final user = ref.watch(
      authNotifierProvider.select((v) => v.valueOrNull),
    );
    final hPad = Responsive.horizontalPadding(context);
    final c = context.sac;

    return Scaffold(
      backgroundColor: c.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async => ref.invalidate(slaDashboardProvider),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── Hero AppBar ────────────────────────────────────────────────
            SliverAppBar(
              expandedHeight: 140,
              floating: true,
              snap: true,
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
                      padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Coordinación',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user?.name != null
                                ? 'Hola, ${user!.name}'
                                : 'Panel de coordinador',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Body ───────────────────────────────────────────────────────
            SliverPadding(
              padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // ── Summary cards ──────────────────────────────────────
                  slaAsync.when(
                    data: (sla) => _SummaryRow(sla: sla),
                    loading: () => const _SummarySkeleton(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),

                  const SizedBox(height: 24),

                  // ── Navigation cards ───────────────────────────────────
                  Text(
                    'Módulos',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: c.text,
                        ),
                  ),
                  const SizedBox(height: 12),

                  _NavCard(
                    icon: HugeIcons.strokeRoundedAward01,
                    color: AppColors.primary,
                    title: 'Investiduras Pendientes',
                    subtitle: 'Validar solicitudes de investidura',
                    onTap: () => context.push(RouteNames.investiturePendingList),
                  ),
                  const SizedBox(height: 10),

                  _NavCard(
                    icon: HugeIcons.strokeRoundedFolder01,
                    color: AppColors.accent,
                    title: 'Revisión de Evidencias',
                    subtitle: 'Aprobar o rechazar carpetas, clases y honores',
                    onTap: () => context.push(RouteNames.coordinatorEvidenceReview),
                  ),
                  const SizedBox(height: 10),

                  _NavCard(
                    icon: HugeIcons.strokeRoundedCalendar04,
                    color: AppColors.secondary,
                    title: 'Aprobaciones de Camporees',
                    subtitle: 'Clubs, miembros y pagos pendientes',
                    onTap: () =>
                        context.push(RouteNames.coordinatorCamporeeApprovals),
                  ),
                  const SizedBox(height: 10),

                  _NavCard(
                    icon: HugeIcons.strokeRoundedAnalytics01,
                    color: AppColors.info,
                    title: 'Dashboard Operativo',
                    subtitle: 'KPIs y métricas SLA en tiempo real',
                    onTap: () => context.push(RouteNames.coordinatorSla),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Summary row ───────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final SlaDashboard sla;

  const _SummaryRow({required this.sla});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.6,
      children: [
        _SummaryTile(
          label: 'Investiduras',
          count: sla.investiture.pending,
          color: AppColors.primary,
          icon: HugeIcons.strokeRoundedAward01,
        ),
        _SummaryTile(
          label: 'Evidencias',
          count: sla.evidence.pending,
          color: AppColors.accent,
          icon: HugeIcons.strokeRoundedFolder01,
        ),
        _SummaryTile(
          label: 'Camporees',
          count: sla.camporee.pending,
          color: AppColors.secondary,
          icon: HugeIcons.strokeRoundedCalendar04,
        ),
        _SummaryTile(
          label: 'Vencidos',
          count: sla.totalOverdue,
          color: AppColors.error,
          icon: HugeIcons.strokeRoundedAlert02,
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final List<List<dynamic>> icon;

  const _SummaryTile({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
        boxShadow: [
          BoxShadow(
            color: c.shadow,
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: HugeIcon(icon: icon, size: 20, color: color),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: count > 0 ? color : c.textTertiary,
                    height: 1.1,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: c.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummarySkeleton extends StatelessWidget {
  const _SummarySkeleton();

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return GridView.count(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.6,
      children: List.generate(
        4,
        (_) => Container(
          decoration: BoxDecoration(
            color: c.border,
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

// ── Navigation card ───────────────────────────────────────────────────────────

class _NavCard extends StatelessWidget {
  final List<List<dynamic>> icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _NavCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  static final _kRadius = BorderRadius.circular(16);

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Material(
      color: c.surface,
      borderRadius: _kRadius,
      child: InkWell(
        borderRadius: _kRadius,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: _kRadius,
            border: Border.all(color: c.border),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: HugeIcon(icon: icon, size: 22, color: color),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: c.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                size: 18,
                color: c.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
