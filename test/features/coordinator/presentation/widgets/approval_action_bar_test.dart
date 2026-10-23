import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/features/coordinator/presentation/widgets/approval_action_buttons.dart';

Widget _app({
  required bool loading,
  VoidCallback? onApprove,
  VoidCallback? onReject,
}) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    home: Scaffold(
      body: const SizedBox.expand(),
      bottomNavigationBar: ApprovalActionBar(
        isLoading: loading,
        approveLabel: 'Aprobar',
        rejectLabel: 'Rechazar',
        onApprove: onApprove ?? () {},
        onReject: onReject ?? () {},
      ),
    ),
  );
}

SacButton _button(WidgetTester tester, String text) => tester
    .widgetList<SacButton>(find.byType(SacButton))
    .singleWhere((button) => button.text == text);

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

    final approve = _button(tester, 'Aprobar');
    final reject = _button(tester, 'Rechazar');

    expect(approve.isLoading, isTrue);
    expect(reject.isLoading, isFalse);
    expect(find.text('Rechazar'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('el otro botón queda deshabilitado mientras se envía',
      (tester) async {
    var rejects = 0;
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
                onReject: () => rejects++,
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Aprobar'));
    await tester.pump();

    expect(_button(tester, 'Rechazar').isEnabled, isFalse);
    expect(_button(tester, 'Aprobar').isEnabled, isFalse);

    await tester.tap(find.text('Rechazar'), warnIfMissed: false);
    await tester.pump();
    expect(rejects, 0);
  });

  testWidgets('los dos botones miden al menos 48 y tienen el mismo ancho',
      (tester) async {
    await tester.pumpWidget(_app(loading: false));

    final reject = find.widgetWithText(SacButton, 'Rechazar');
    final approve = find.widgetWithText(SacButton, 'Aprobar');

    expect(tester.getSize(reject).height, greaterThanOrEqualTo(48));
    expect(tester.getSize(approve).height, greaterThanOrEqualTo(48));

    final ratio = tester.getSize(approve).width / tester.getSize(reject).width;
    expect(ratio, closeTo(1.0, 0.01));
    // 12 pt gap between the two buttons.
    expect(
      tester.getTopLeft(approve).dx - tester.getTopRight(reject).dx,
      closeTo(12, 0.01),
    );
  });

  testWidgets('tiene un borde superior fino y respeta el área segura',
      (tester) async {
    tester.view.padding = const FakeViewPadding(bottom: 34);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(loading: false));

    final bar = find.byType(ApprovalActionBar);
    final decoration = tester
        .widget<DecoratedBox>(
          find.descendant(of: bar, matching: find.byType(DecoratedBox)).first,
        )
        .decoration as BoxDecoration;
    final border = decoration.border! as Border;
    expect(border.top.width, 1);
    expect(border.bottom, BorderSide.none);

    // Buttons clear the bottom inset instead of touching the screen edge.
    final screenHeight = tester.view.physicalSize.height;
    expect(
      tester.getBottomLeft(find.widgetWithText(SacButton, 'Aprobar')).dy,
      lessThanOrEqualTo(screenHeight - 34),
    );
  });

  testWidgets('los callbacks se llaman al pulsar', (tester) async {
    var approves = 0;
    var rejects = 0;
    await tester.pumpWidget(
      _app(
        loading: false,
        onApprove: () => approves++,
        onReject: () => rejects++,
      ),
    );

    await tester.tap(find.text('Rechazar'));
    await tester.pump();
    await tester.tap(find.text('Aprobar'));
    await tester.pump();

    expect(rejects, 1);
    expect(approves, 1);
  });
}
