/// Tests for SLADashboardView (Dashboard Operativo).
///
/// Investiture KPI, pipeline and weekly throughput come from the retired
/// investiture pipeline, so the view only shows the evidence KPI.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/coordinator/domain/entities/sla_dashboard.dart';
import 'package:sacdia_app/features/coordinator/presentation/providers/coordinator_providers.dart';
import 'package:sacdia_app/features/coordinator/presentation/views/sla_dashboard_view.dart';

const _sla = SlaDashboard(
  investiture: SlaStat(pending: 35, avgDays: 4, overdue: 2),
  evidence: SlaStat(pending: 6, avgDays: 0, overdue: 0),
  camporee: SlaStat(pending: 0, avgDays: 0, overdue: 0),
  throughput: [ThroughputPoint(week: '2026-W40', approved: 5, rejected: 1)],
  pipeline: [PipelineStage(stage: 'Enviado para validación', count: 3)],
);

void main() {
  testWidgets('shows only the evidence KPI', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          slaDashboardProvider.overrideWith((ref) async => _sla),
        ],
        child: const MaterialApp(home: SLADashboardView()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('coordinator.summary.evidence'.tr()), findsOneWidget);
    expect(find.text('coordinator.summary.investitures'.tr()), findsNothing);
    expect(find.text('Enviado para validación'), findsNothing);
    expect(find.text('35'), findsNothing);

    // Dispose the view so its 60 s auto-refresh timer is cancelled.
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
