import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/master_honors/domain/entities/user_master_honor.dart';
import 'package:sacdia_app/features/master_honors/presentation/widgets/master_honor_badge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrap(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 360,
            child: child,
          ),
        ),
      ),
    );
  }

  testWidgets('current master honor renders normal badge', (tester) async {
    await tester.pumpWidget(
      wrap(
        MasterHonorBadge(
          honor: UserMasterHonor(
            userMasterHonorId: 1,
            masterHonorId: 1,
            name: 'Maestría de Servicio',
            status: 'AWARDED',
            isCurrent: true,
            displayStatusLabel: 'Vigente',
            awardedAt: DateTime(2026, 6, 3),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Maestría de Servicio'), findsOneWidget);
    expect(find.text('Vigente'), findsOneWidget);
    expect(find.text('No vigente'), findsNothing);
  });

  testWidgets('revoked or retired master honor shows no vigente status',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        MasterHonorBadge(
          honor: UserMasterHonor(
            userMasterHonorId: 2,
            masterHonorId: 2,
            name: 'Maestría de Liderazgo',
            status: 'REVOKED',
            isCurrent: false,
            displayStatusLabel: 'No vigente',
            awardedAt: DateTime(2026, 2, 12),
            revokedAt: DateTime(2026, 6, 1),
            statusReason: 'No cumple con requisitos vigentes',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Maestría de Liderazgo'), findsOneWidget);
    expect(find.text('No vigente'), findsOneWidget);
  });
}
