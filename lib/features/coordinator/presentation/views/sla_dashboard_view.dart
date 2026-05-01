import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_loading.dart';
import '../providers/coordinator_providers.dart';
import '../widgets/sla_stat_card.dart';
import '../widgets/sla_pipeline_chart.dart';

/// Dashboard SLA operativo del coordinador.
///
/// Muestra KPIs de los tres procesos (investiture, evidence, camporee),
/// pipeline de revisión y throughput semanal.
/// Se auto-refresca cada 60 segundos.
class SLADashboardView extends ConsumerStatefulWidget {
  const SLADashboardView({super.key});

  @override
  ConsumerState<SLADashboardView> createState() => _SLADashboardViewState();
}

class _SLADashboardViewState extends ConsumerState<SLADashboardView> {
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    // Auto-refresh every 60 seconds
    _autoRefreshTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => ref.invalidate(slaDashboardProvider),
    );
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slaAsync = ref.watch(slaDashboardProvider);
    final hPad = Responsive.horizontalPadding(context);
    final c = context.sac;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        title: Text('coordinator.sla.dashboard.title'.tr()),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(slaDashboardProvider),
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedRefresh,
              size: 22,
            ),
            tooltip: 'coordinator.sla.dashboard.refresh_tooltip'.tr(),
          ),
        ],
      ),
      body: SafeArea(
        child: slaAsync.when(
          data: (sla) => RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => ref.invalidate(slaDashboardProvider),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Section label ──────────────────────────────────────
                  Text(
                    'coordinator.sla.dashboard.current_status'.tr(),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: c.text,
                        ),
                  ),
                  const SizedBox(height: 12),

                  // ── KPI cards ──────────────────────────────────────────
                  SlaStatCard(
                    title: 'coordinator.summary.investitures'.tr(),
                    stat: sla.investiture,
                    accentColor: AppColors.primary,
                    icon: HugeIcons.strokeRoundedAward01,
                  ),
                  const SizedBox(height: 10),
                  SlaStatCard(
                    title: 'coordinator.summary.evidence'.tr(),
                    stat: sla.evidence,
                    accentColor: AppColors.accent,
                    icon: HugeIcons.strokeRoundedFolder01,
                  ),
                  const SizedBox(height: 10),
                  SlaStatCard(
                    title: 'coordinator.summary.camporees'.tr(),
                    stat: sla.camporee,
                    accentColor: AppColors.secondary,
                    icon: HugeIcons.strokeRoundedCalendar04,
                  ),

                  const SizedBox(height: 24),

                  // ── Pipeline ───────────────────────────────────────────
                  if (sla.pipeline.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: c.border),
                      ),
                      child: SlaPipelineChart(stages: sla.pipeline),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Throughput ─────────────────────────────────────────
                  if (sla.throughput.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: c.border),
                      ),
                      child: SlaThroughputChart(data: sla.throughput),
                    ),
                  ],

                  // ── Auto-refresh note ──────────────────────────────────
                  const SizedBox(height: 16),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedClock01,
                          size: 12,
                          color: c.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'coordinator.sla.dashboard.auto_refresh_note'.tr(),
                          style: TextStyle(
                            fontSize: 11,
                            color: c.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          loading: () => const Center(child: SacLoading()),
          error: (error, _) => _buildError(context, ref, error),
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, WidgetRef ref, Object error) {
    final c = context.sac;
    final msg = error.toString().replaceFirst('Exception: ', '');
    final is403 = msg.contains('permiso') || msg.contains('403');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HugeIcon(
              icon: is403
                  ? HugeIcons.strokeRoundedLockKey
                  : HugeIcons.strokeRoundedAlert02,
              size: 56,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            Text(
              is403
                  ? 'coordinator.sla.dashboard.access_restricted'.tr()
                  : 'coordinator.sla.dashboard.error_load'.tr(),
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              is403
                  ? 'coordinator.sla.dashboard.access_restricted_msg'.tr()
                  : msg,
              style: TextStyle(fontSize: 14, color: c.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (!is403) ...[
              const SizedBox(height: 24),
              SacButton.primary(
                text: 'coordinator.sla.dashboard.retry'.tr(),
                icon: HugeIcons.strokeRoundedRefresh,
                onPressed: () => ref.invalidate(slaDashboardProvider),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
