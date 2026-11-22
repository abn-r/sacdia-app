import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/widgets/status_progress/sac_state_panel.dart';
import 'package:sacdia_app/core/widgets/status_progress/sac_status_style.dart';

Widget _app({required VoidCallback onTap, ThemeData? theme}) => MaterialApp(
      theme: theme ?? AppTheme.lightTheme,
      home: Scaffold(
        body: Builder(
          builder: (context) => SacStatePanel(
            style: SacStatusStyle.of(
              context,
              SacStatusKind.review,
              label: 'En revisión',
            ),
            title: 'En revisión',
            message: 'El campo revisa el pago',
            stepLabel: 'Paso 3 de 4',
            semanticsHint: 'Muestra todos los estados',
            onTap: onTap,
          ),
        ),
      ),
    );

void main() {
  testWidgets('renders title, message and step', (tester) async {
    await tester.pumpWidget(_app(onTap: () {}));
    expect(find.text('En revisión'), findsOneWidget);
    expect(find.text('El campo revisa el pago'), findsOneWidget);
    expect(find.text('Paso 3 de 4'), findsOneWidget);
  });

  testWidgets('tap calls onTap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_app(onTap: () => taps++));
    await tester.tap(find.byType(SacStatePanel));
    expect(taps, 1);
  });

  testWidgets('exposes a joined semantics label and the hint', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(onTap: () {}));
    final node = tester.getSemantics(find.byType(SacStatePanel));
    expect(node.label, 'En revisión. El campo revisa el pago. Paso 3 de 4');
    expect(node.hint, 'Muestra todos los estados');
    handle.dispose();
  });

  testWidgets('renders in dark theme', (tester) async {
    await tester.pumpWidget(_app(onTap: () {}, theme: AppTheme.darkTheme));
    expect(find.text('En revisión'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('semanticsLabel replaces the joined label', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => SacStatePanel(
              style: SacStatusStyle.of(
                context,
                SacStatusKind.review,
                label: 'Enviado',
              ),
              title: 'Enviado',
              message: 'El 19 nov.',
              stepLabel: 'Paso 2 de 3',
              semanticsLabel: 'Estado: Enviado, paso 2 de 3',
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    final node = tester.getSemantics(find.byType(SacStatePanel));
    expect(node.label, 'Estado: Enviado, paso 2 de 3');
    handle.dispose();
  });

  group('stateKey', () {
    Widget panel(String title, {String? stateKey}) => MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => SacStatePanel(
                style: SacStatusStyle.of(
                  context,
                  SacStatusKind.review,
                  label: 'Subiendo',
                ),
                title: title,
                stateKey: stateKey,
              ),
            ),
          ),
        );

    testWidgets('a live number in the title updates without a cross-fade',
        (tester) async {
      await tester.pumpWidget(panel('Subiendo 10 %', stateKey: 'uploading'));
      await tester.pumpWidget(panel('Subiendo 11 %', stateKey: 'uploading'));
      await tester.pump(const Duration(milliseconds: 20));

      // Same state: the old title is not kept alive by the switcher.
      expect(find.text('Subiendo 10 %'), findsNothing);
      expect(find.text('Subiendo 11 %'), findsOneWidget);
    });

    testWidgets('a new stateKey still animates the change of state',
        (tester) async {
      await tester.pumpWidget(panel('Subiendo 100 %', stateKey: 'uploading'));
      await tester.pumpWidget(panel('Leyendo', stateKey: 'reading'));
      await tester.pump(const Duration(milliseconds: 20));

      // Mid-transition both states are on screen.
      expect(find.text('Subiendo 100 %'), findsOneWidget);
      expect(find.text('Leyendo'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('Subiendo 100 %'), findsNothing);
    });

    testWidgets('without a stateKey the title keys the change (as before)',
        (tester) async {
      await tester.pumpWidget(panel('Enviado'));
      await tester.pumpWidget(panel('Validado'));
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.text('Enviado'), findsOneWidget);
      expect(find.text('Validado'), findsOneWidget);
    });
  });
}
