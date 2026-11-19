import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/errors/exceptions.dart';
import 'package:sacdia_app/features/qr/domain/entities/qr_scan_result.dart';
import 'package:sacdia_app/features/qr/presentation/views/qr_scanner_view.dart';

import '../family/family_test_harness.dart';

QrScanResult _result(
        {required bool alreadyPresent, bool withAttendance = true}) =>
    QrScanResult(
      member: const ScannedMember(
        userId: 'u1',
        fullName: 'Lucía Pérez',
        clubName: 'Club Orión',
        sectionName: 'Conquistadores',
      ),
      attendance: withAttendance
          ? ScannedAttendance(
              registered: !alreadyPresent,
              alreadyPresent: alreadyPresent,
              activityId: 5,
            )
          : null,
      scannedAt: DateTime(2026, 11, 19),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initLocalization);

  Future<void> pumpSheet(
    WidgetTester tester,
    AsyncValue<QrScanResult?> state, {
    int? count,
    int? total,
  }) async {
    await pumpFamilyApp(
      tester,
      overrides: const [],
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: QrScanResultSheet(
                state: state,
                registeredCount: count,
                total: total,
              ),
            ),
          ),
        ),
      ],
    );
    await tester.pumpAndSettle();
  }

  testWidgets('success shows the person, the count with total and the CTA',
      (tester) async {
    await pumpSheet(
      tester,
      AsyncValue.data(_result(alreadyPresent: false)),
      count: 13,
      total: 30,
    );

    expect(find.text('Lucía Pérez'), findsOneWidget);
    expect(find.text('Asistencia registrada · 13 de 30'), findsOneWidget);
    expect(find.byKey(const ValueKey('scan-check')), findsOneWidget);
    expect(find.text('Escanear otro'), findsOneWidget);
  });

  testWidgets('omits "de total" when the roster is unavailable',
      (tester) async {
    await pumpSheet(tester, AsyncValue.data(_result(alreadyPresent: false)));

    expect(find.text('Asistencia registrada'), findsOneWidget);
    expect(find.textContaining('·'), findsOneWidget); // club · section only
  });

  testWidgets('already present variant', (tester) async {
    await pumpSheet(
      tester,
      AsyncValue.data(_result(alreadyPresent: true)),
      count: 13,
      total: 30,
    );

    expect(find.text('Ya estaba registrado'), findsOneWidget);
    expect(find.textContaining('13 de 30'), findsNothing);
  });

  testWidgets('error uses the same sheet layout with a retry action',
      (tester) async {
    await pumpSheet(
      tester,
      AsyncValue.error(ConnectionException(message: 'x'), StackTrace.empty),
    );

    expect(find.text('No se pudo validar el QR'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });
}
