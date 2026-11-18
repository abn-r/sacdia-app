import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/page_transitions.dart';
import 'package:sacdia_app/core/errors/user_error_message.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_empty_state.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';

import '../../domain/entities/monthly_report.dart';
import '../providers/monthly_reports_providers.dart';
import '../widgets/monthly_report_history.dart';
import '../widgets/monthly_report_motion.dart';
import 'monthly_report_detail_view.dart';

/// Informes de una inscripción (desde Finanzas). Es el mismo historial que el
/// inicio de Reportes: filas agrupadas por año con su chip de estado.
class MonthlyReportsListView extends ConsumerWidget {
  final String enrollmentId;

  const MonthlyReportsListView({
    super.key,
    required this.enrollmentId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsAsync =
        ref.watch(monthlyReportsByEnrollmentProvider(enrollmentId));

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: context.sac.background,
      appBar:
          SacTopBar(title: 'monthly_reports.list.title'.tr(), frosted: true),
      body: SacFrostedVeil(
        child: Builder(
          builder: (context) => reportsAsync.when(
            loading: () => const MonthlyReportSkeletonList(),
            error: (e, _) => SacErrorState(
              title: 'common.error_state.title'.tr(),
              message: userErrorMessage(e),
              onRetry: () => ref
                  .invalidate(monthlyReportsByEnrollmentProvider(enrollmentId)),
            ),
            data: (reports) {
              if (reports.isEmpty) {
                return SacEmptyState(
                  icon: HugeIcons.strokeRoundedFile01,
                  title: 'monthly_reports.list.empty_title'.tr(),
                  body: 'monthly_reports.list.empty_subtitle'.tr(),
                );
              }

              return RefreshIndicator(
                color: SacAccent.of(context).color,
                onRefresh: () async => ref.invalidate(
                    monthlyReportsByEnrollmentProvider(enrollmentId)),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: SacTopBar.paddingBelowBar(
                      context, const EdgeInsets.only(bottom: 32)),
                  children: [
                    MonthlyReportYearGroups(
                      reports: [
                        for (final report in reports)
                          VisibleMonthlyReport.fromReport(report),
                      ],
                      onOpen: (report) => Navigator.push(
                        context,
                        SacSharedAxisRoute(
                          builder: (_) =>
                              MonthlyReportDetailView(reportId: report.id),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
