import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/status_progress/sac_status_style.dart';
import 'package:sacdia_app/features/monthly_reports/domain/entities/monthly_report.dart';
import 'package:sacdia_app/features/monthly_reports/presentation/widgets/monthly_report_status_chip.dart';

import '../support/monthly_reports_harness.dart';

void main() {
  setUpAll(setUpMonthlyReportsLocalization);

  testWidgets('every status has its own colors and icon', (tester) async {
    late BuildContext captured;
    await pumpMonthlyReportsApp(
      tester,
      home: Builder(builder: (context) {
        captured = context;
        return const SizedBox();
      }),
    );

    final styles = {
      for (final status in MonthlyReportStatus.values)
        status: monthlyReportStatusStyle(captured, status),
    };
    final c = captured.sac;

    expect(styles[MonthlyReportStatus.draft]!.container, c.warningContainer);
    expect(styles[MonthlyReportStatus.submitted]!.container, c.infoContainer);
    expect(styles[MonthlyReportStatus.approved]!.container, c.successContainer);
    expect(styles[MonthlyReportStatus.rejected]!.container, c.errorContainer);
    expect(
      styles[MonthlyReportStatus.rejected]!.kind,
      SacStatusKind.rejected,
    );

    // Generated and approved no longer share the same green.
    expect(
      styles[MonthlyReportStatus.generated]!.container,
      isNot(styles[MonthlyReportStatus.approved]!.container),
    );

    // Five statuses, five containers, five icons: color is never the only signal.
    expect(styles.values.map((s) => s.container).toSet(), hasLength(5));
    expect(styles.values.map((s) => s.icon).toSet(), hasLength(5));
    expect(styles.values.map((s) => s.label).toSet(), hasLength(5));
  });

  testWidgets('the chip shows the icon and the translated name',
      (tester) async {
    await pumpMonthlyReportsApp(
      tester,
      home: const Scaffold(
        body: Column(
          children: [
            MonthlyReportStatusChip(status: MonthlyReportStatus.draft),
            MonthlyReportStatusChip(status: MonthlyReportStatus.generated),
            MonthlyReportStatusChip(status: MonthlyReportStatus.submitted),
            MonthlyReportStatusChip(status: MonthlyReportStatus.approved),
            MonthlyReportStatusChip(status: MonthlyReportStatus.rejected),
          ],
        ),
      ),
    );

    expect(find.text('Borrador'), findsOneWidget);
    expect(find.text('Generado'), findsOneWidget);
    expect(find.text('En revisión'), findsOneWidget);
    expect(find.text('Aprobado'), findsOneWidget);
    expect(find.text('Rechazado'), findsOneWidget);
    // One icon per chip.
    expect(
      find.descendant(
        of: find.byType(MonthlyReportStatusChip),
        matching: find.byType(HugeIcon),
      ),
      findsNWidgets(5),
    );
  });
}
