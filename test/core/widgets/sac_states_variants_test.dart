import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_empty_state.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';

Widget _host(Widget child) => MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('scrollable error state centers and supports pull to refresh',
      (tester) async {
    var refreshed = 0;
    await tester.pumpWidget(
      _host(
        RefreshIndicator(
          onRefresh: () async => refreshed++,
          child: const SacErrorState(title: 'Falló', scrollable: true),
        ),
      ),
    );
    final center = tester.getCenter(find.text('Falló'));
    final screen = tester.getCenter(find.byType(Scaffold));
    expect((center.dy - screen.dy).abs(), lessThan(80));

    await tester.fling(find.text('Falló'), const Offset(0, 300), 1000);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(refreshed, 1);
  });

  testWidgets('scrollable empty state supports pull to refresh',
      (tester) async {
    var refreshed = 0;
    await tester.pumpWidget(
      _host(
        RefreshIndicator(
          onRefresh: () async => refreshed++,
          child: const SacEmptyState(title: 'Vacío', scrollable: true),
        ),
      ),
    );
    await tester.fling(find.text('Vacío'), const Offset(0, 300), 1000);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(refreshed, 1);
  });

  testWidgets('error inline shows message and retry only with callback',
      (tester) async {
    await tester.pumpWidget(
      _host(const SacErrorState.inline(message: 'No se pudo cargar')),
    );
    expect(find.text('No se pudo cargar'), findsOneWidget);
    expect(find.byType(SacButton), findsNothing);

    var taps = 0;
    await tester.pumpWidget(
      _host(SacErrorState.inline(message: 'Error', onRetry: () => taps++)),
    );
    await tester.tap(find.byType(SacButton));
    expect(taps, 1);
  });

  testWidgets('empty inline shows title and body', (tester) async {
    await tester.pumpWidget(
      _host(const SacEmptyState.inline(title: 'Sin datos', body: 'Nada aún')),
    );
    expect(find.text('Sin datos'), findsOneWidget);
    expect(find.text('Nada aún'), findsOneWidget);
  });
}
