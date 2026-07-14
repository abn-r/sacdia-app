import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';

void main() {
  testWidgets('mantiene defaults de una línea para compatibilidad',
      (tester) async {
    await _pumpButton(
      tester,
      const SacButton(text: 'Etiqueta'),
    );

    final label = tester.widget<Text>(find.text('Etiqueta'));
    expect(label.maxLines, 1);
    expect(label.overflow, TextOverflow.ellipsis);
  });

  testWidgets('permite dos líneas y crece con text scaling 200%',
      (tester) async {
    await _pumpButton(
      tester,
      SacButton.primary(
        text: 'Confirmar la inscripción de toda mi sección',
        onPressed: () {},
        labelMaxLines: 2,
        labelOverflow: TextOverflow.visible,
      ),
      textScaler: const TextScaler.linear(2),
      width: 280,
    );

    final label = tester.widget<Text>(
      find.text('Confirmar la inscripción de toda mi sección'),
    );
    expect(label.maxLines, 2);
    expect(label.overflow, TextOverflow.visible);
    expect(tester.getSize(find.byType(ElevatedButton)).height, greaterThan(48));
    expect(tester.takeException(), isNull);
  });

  testWidgets('resuelve overrides de foreground background y borde',
      (tester) async {
    const foreground = Color(0xFF0F172A);
    const background = Color(0xFFF06151);
    const border = Color(0xFF64748B);

    await _pumpButton(
      tester,
      SacButton.outline(
        text: 'Reintentar',
        onPressed: () {},
        backgroundColor: background,
        textColor: foreground,
        borderColor: border,
      ),
    );

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.style?.backgroundColor?.resolve({}), background);
    expect(button.style?.foregroundColor?.resolve({}), foreground);
    final shape = button.style?.shape?.resolve({}) as RoundedRectangleBorder;
    expect(shape.side.color, border);
  });

  testWidgets('loading anuncia estado traducido como live region',
      (tester) async {
    await _pumpButton(
      tester,
      const SacButton.primary(
        text: 'Confirmar',
        isLoading: true,
        loadingSemanticLabel: 'Inscribiendo sección',
      ),
    );

    final semantics = tester.widget<Semantics>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Inscribiendo sección',
      ),
    );
    expect(semantics.properties.liveRegion, isTrue);
  });

  testWidgets('disableAnimations evita la escala de presión', (tester) async {
    await _pumpButton(
      tester,
      SacButton.primary(text: 'Continuar', onPressed: () {}),
      disableAnimations: true,
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(ElevatedButton)),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final transition = tester.widget<ScaleTransition>(
      find.byWidgetPredicate(
        (widget) => widget is ScaleTransition && widget.child is ElevatedButton,
      ),
    );
    expect(transition.scale.value, 1);
    await gesture.up();
  });
}

Future<void> _pumpButton(
  WidgetTester tester,
  Widget button, {
  TextScaler textScaler = TextScaler.noScaling,
  double width = 320,
  bool disableAnimations = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: MediaQuery(
        data: MediaQueryData(
          textScaler: textScaler,
          disableAnimations: disableAnimations,
        ),
        child: Scaffold(
          body: Center(
            child: SizedBox(width: width, child: button),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}
