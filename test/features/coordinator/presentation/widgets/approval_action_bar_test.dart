import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/features/coordinator/presentation/widgets/approval_action_buttons.dart';

void main() {
  testWidgets('el spinner se queda en la acción pulsada', (tester) async {
    var loading = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return ApprovalActionBar(
                isLoading: loading,
                approveLabel: 'Aprobar',
                rejectLabel: 'Rechazar',
                onApprove: () => setState(() => loading = true),
                onReject: () => setState(() => loading = true),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Aprobar'));
    await tester.pump();

    final buttons = tester.widgetList<SacButton>(find.byType(SacButton));
    final approve = buttons.singleWhere((button) => button.text == 'Aprobar');
    final reject = buttons.singleWhere((button) => button.text == 'Rechazar');

    expect(approve.isLoading, isTrue);
    expect(reject.isLoading, isFalse);
    expect(find.text('Rechazar'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
