import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_empty_state.dart';

void main() {
  testWidgets('renders title and optional body without CTA', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: SacEmptyState(
            title: 'No hay unidades',
            body: 'Crea la primera unidad del club.',
          ),
        ),
      ),
    );

    expect(find.text('No hay unidades'), findsOneWidget);
    expect(find.text('Crea la primera unidad del club.'), findsOneWidget);
    expect(find.byType(SacButton), findsNothing);
    expect(find.byType(HugeIcon), findsOneWidget);
  });

  testWidgets('shows CTA only when label and callback are both set',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: SacEmptyState(
            title: 'No hay artículos',
            actionLabel: 'Agregar',
            onAction: () => taps++,
          ),
        ),
      ),
    );

    expect(find.widgetWithText(SacButton, 'Agregar'), findsOneWidget);
    await tester.tap(find.text('Agregar'));
    expect(taps, 1);
  });
}
