import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/widgets/status_progress/status_progress.dart';

const _labels = SacStateKindLabels(
  done: 'Hecho',
  current: 'Actual',
  rejected: 'Rechazado',
  pending: 'Pendiente',
);

const _steps = [
  SacStateStep(
      kind: SacStateKind.done, title: 'Orden emitida', detail: '7 feb'),
  SacStateStep(
    kind: SacStateKind.current,
    title: 'Pagar y subir el recibo',
    detail: 'Antes del 21 feb',
  ),
  SacStateStep(kind: SacStateKind.pending, title: 'El campo revisa el pago'),
  SacStateStep(
    kind: SacStateKind.pending,
    title: 'Quedan asegurados',
    detail: 'Todo el año eclesiástico 2027',
  ),
];

Widget _app(Widget child) => MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: child),
    );

class _Host extends StatelessWidget {
  const _Host();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Builder(
        builder: (context) => SacStatePanel(
          style: SacStatusStyle.of(
            context,
            SacStatusKind.review,
            label: 'Falta el recibo de pago',
          ),
          title: 'Falta el recibo de pago',
          message: 'Paga \$700.00 y sube el recibo antes del 21 feb.',
          stepLabel: 'Paso 2 de 4',
          semanticsHint: 'Muestra todos los estados',
          onTap: () => showSacStatesSheet(
            context,
            title: 'Estados de la orden',
            subtitle: 'ORD20270044',
            steps: _steps,
            kindLabels: _labels,
          ),
        ),
      ),
    );
  }
}

void main() {
  testWidgets('the panel shows only the current state and the step number',
      (tester) async {
    await tester.pumpWidget(_app(const _Host()));

    expect(find.text('Falta el recibo de pago'), findsOneWidget);
    expect(find.text('Paso 2 de 4'), findsOneWidget);
    // No always-visible path: the other states stay behind the tap.
    expect(find.text('Orden emitida'), findsNothing);
    expect(find.text('El campo revisa el pago'), findsNothing);
    expect(find.byType(SacStepPath), findsNothing);
  });

  testWidgets('tapping the panel opens the sheet with every state in order',
      (tester) async {
    await tester.pumpWidget(_app(const _Host()));

    await tester.tap(find.byType(SacStatePanel));
    await tester.pumpAndSettle();

    expect(find.text('Estados de la orden'), findsOneWidget);
    expect(find.text('ORD20270044'), findsOneWidget);
    final titles = [
      'Orden emitida',
      'Pagar y subir el recibo',
      'El campo revisa el pago',
      'Quedan asegurados',
    ];
    var lastY = -1.0;
    for (final title in titles) {
      final y = tester.getTopLeft(find.text(title)).dy;
      expect(y, greaterThan(lastY), reason: '$title out of order');
      lastY = y;
    }
    expect(find.text('7 feb'), findsOneWidget);
    expect(find.text('Antes del 21 feb'), findsOneWidget);
  });

  testWidgets('done steps carry a check and a rejected one a cross',
      (tester) async {
    await tester.pumpWidget(
      _app(
        const SacStatesSheet(
          title: 'Estados',
          kindLabels: _labels,
          steps: [
            SacStateStep(kind: SacStateKind.done, title: 'Emitida'),
            SacStateStep(kind: SacStateKind.done, title: 'Enviado'),
            SacStateStep(
              kind: SacStateKind.rejected,
              title: 'Rechazado por el campo',
              detail: 'Sube otro recibo',
            ),
            SacStateStep(
                kind: SacStateKind.pending, title: 'Quedan asegurados'),
          ],
        ),
      ),
    );

    // One dot per step, drawn as circles of 24.
    final dots = find.byWidgetPredicate(
      (w) =>
          w is Container &&
          w.constraints?.maxWidth == 24 &&
          w.constraints?.maxHeight == 24,
    );
    expect(dots, findsNWidgets(4));
    expect(find.text('Sube otro recibo'), findsOneWidget);
  });

  testWidgets('each row announces its state to a screen reader',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        const SacStatesSheet(
          title: 'Estados',
          kindLabels: _labels,
          steps: _steps,
        ),
      ),
    );

    expect(
      find.bySemanticsLabel('Orden emitida. 7 feb. Hecho'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
          'Pagar y subir el recibo. Antes del 21 feb. Actual'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('El campo revisa el pago. Pendiente'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('the panel is a button with its hint', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(const _Host()));

    final node = tester.getSemantics(find.byType(SacStatePanel));
    expect(node.hint, 'Muestra todos los estados');
    expect(
      node.label,
      'Falta el recibo de pago. Paga \$700.00 y sube el recibo antes del 21 feb.. Paso 2 de 4',
    );
    handle.dispose();
  });

  testWidgets('a detour sits apart under a divider, off the step line',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        const SacStatesSheet(
          title: 'Estados',
          kindLabels: _labels,
          steps: _steps,
          detour: SacStateStep(
            kind: SacStateKind.rejected,
            title: 'Por corregir',
            detail: 'Devuelto el 15 nov',
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('states-sheet-detour-divider')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('states-sheet-detour')), findsOneWidget);
    expect(find.text('Por corregir'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Por corregir. Devuelto el 15 nov. Rechazado'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('without a detour there is no divider', (tester) async {
    await tester.pumpWidget(
      _app(const SacStatesSheet(
        title: 'Estados',
        kindLabels: _labels,
        steps: _steps,
      )),
    );
    expect(find.byKey(const ValueKey('states-sheet-detour-divider')),
        findsNothing);
  });
}
