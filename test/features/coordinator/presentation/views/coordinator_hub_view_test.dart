/// Tests for CoordinatorHubView summary cards.
///
/// The investiture card was removed after the legacy investiture pipeline
/// shutdown: coordinators no longer authorize investitures, so the hub only
/// shows evidence, sections and overdue counts.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/coordinator/domain/entities/coordinator_scope.dart';
import 'package:sacdia_app/features/coordinator/domain/entities/sla_dashboard.dart';
import 'package:sacdia_app/features/coordinator/presentation/providers/coordinator_providers.dart';
import 'package:sacdia_app/features/coordinator/presentation/views/coordinator_hub_view.dart';

class _FakeAuthNotifier extends AuthNotifier {
  @override
  Future<UserEntity?> build() async => const UserEntity(
        id: 'coord-test-id',
        email: 'coord@test.com',
        name: 'Carlos',
        postRegisterComplete: true,
      );
}

const _sla = SlaDashboard(
  investiture: SlaStat(pending: 35, avgDays: 0, overdue: 0),
  evidence: SlaStat(pending: 6, avgDays: 0, overdue: 2),
  camporee: SlaStat(pending: 0, avgDays: 0, overdue: 1),
  throughput: [],
  pipeline: [],
);

Future<void> _pumpHub(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authNotifierProvider.overrideWith(() => _FakeAuthNotifier()),
        slaDashboardProvider.overrideWith((ref) async => _sla),
        coordinatorScopeProvider.overrideWith(
          (ref) async => const CoordinatorScope(
            isCoordinator: true,
            clubSectionIds: [2],
          ),
        ),
      ],
      child: const MaterialApp(home: CoordinatorHubView()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows evidence, sections and overdue summary cards',
      (tester) async {
    await _pumpHub(tester);

    expect(find.text('coordinator.summary.evidence'.tr()), findsOneWidget);
    expect(find.text('coordinator.summary.sections'.tr()), findsOneWidget);
    expect(find.text('coordinator.summary.overdue'.tr()), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('does not show the retired investiture summary card',
      (tester) async {
    await _pumpHub(tester);

    expect(find.text('coordinator.summary.investitures'.tr()), findsNothing);
    expect(find.text('35'), findsNothing);
  });
}
