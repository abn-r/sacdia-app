import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';

Widget _host(Widget child) => MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('renders title and message without a retry button by default',
      (tester) async {
    await tester.pumpWidget(
      _host(
        const SacErrorState(
          title: 'No pudimos cargar los datos',
          message: 'Revisa tu conexión e inténtalo de nuevo.',
        ),
      ),
    );

    expect(find.text('No pudimos cargar los datos'), findsOneWidget);
    expect(
      find.text('Revisa tu conexión e inténtalo de nuevo.'),
      findsOneWidget,
    );
    expect(find.byType(HugeIcon), findsOneWidget);
    expect(find.byType(SacButton), findsNothing);
  });

  testWidgets('shows a retry button that calls onRetry', (tester) async {
    var retries = 0;
    await tester.pumpWidget(
      _host(
        SacErrorState(
          title: 'Error',
          retryLabel: 'Reintentar',
          onRetry: () => retries++,
        ),
      ),
    );

    expect(find.widgetWithText(SacButton, 'Reintentar'), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    expect(retries, 1);
  });

  testWidgets('forbidden variant uses the lock icon and has no retry',
      (tester) async {
    await tester.pumpWidget(_host(const SacErrorState.forbidden()));

    final icon = tester.widget<HugeIcon>(find.byType(HugeIcon));
    expect(icon.icon, HugeIcons.strokeRoundedLockKey);
    // Without EasyLocalization the keys render as-is.
    expect(find.text('common.error_state.forbidden_title'), findsOneWidget);
    expect(find.text('common.error_state.forbidden_message'), findsOneWidget);
    expect(find.byType(SacButton), findsNothing);
  });

  testWidgets('forbidden variant accepts custom copy and padding',
      (tester) async {
    await tester.pumpWidget(
      _host(
        const SacErrorState.forbidden(
          title: 'Acceso restringido',
          message: 'Solo coordinadores pueden entrar.',
          padding: EdgeInsets.only(top: 120, left: 32, right: 32),
        ),
      ),
    );

    expect(find.text('Acceso restringido'), findsOneWidget);
    expect(find.text('Solo coordinadores pueden entrar.'), findsOneWidget);
    final scroll = tester.widget<SingleChildScrollView>(
      find.byType(SingleChildScrollView),
    );
    expect(
        scroll.padding, const EdgeInsets.only(top: 120, left: 32, right: 32));
  });
}
