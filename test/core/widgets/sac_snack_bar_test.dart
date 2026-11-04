import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';

void main() {
  group('SacSnackBar', () {
    testWidgets('hides the previous snackbar before showing a new one',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () {
                  SacSnackBar.show(context, 'primero');
                  SacSnackBar.show(context, 'segundo');
                },
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('go'));
      await tester.pump();

      expect(find.text('primero'), findsNothing);
      expect(find.text('segundo'), findsOneWidget);
    });

    testWidgets('error toast uses the error color', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    SacSnackBar.show(context, 'boom', isError: true),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('go'));
      await tester.pump();

      final bar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(bar.backgroundColor, AppColors.error);
      expect(find.text('boom'), findsOneWidget);
    });

    Future<void> pumpToast(
      WidgetTester tester,
      ThemeData theme,
      void Function(BuildContext) show,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => show(context),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pump();
    }

    HugeIcon successIcon(WidgetTester tester) => tester.widget<HugeIcon>(
          find.byWidgetPredicate(
            (w) =>
                w is HugeIcon &&
                w.icon == HugeIcons.strokeRoundedCheckmarkCircle02,
          ),
        );

    testWidgets('success keeps neutral bg and adds a bright check in light',
        (tester) async {
      await pumpToast(
        tester,
        AppTheme.lightTheme,
        (c) => SacSnackBar.show(c, 'listo', isSuccess: true),
      );
      expect(tester.widget<SnackBar>(find.byType(SnackBar)).backgroundColor,
          isNull);
      expect(successIcon(tester).color, const Color(0xFF4FBF9F));
    });

    testWidgets('success check is deep green in the dark theme',
        (tester) async {
      await pumpToast(
        tester,
        AppTheme.darkTheme,
        (c) => SacSnackBar.show(c, 'listo', isSuccess: true),
      );
      expect(successIcon(tester).color, const Color(0xFF1E6B55));
    });

    testWidgets('success keeps a caller-provided leading', (tester) async {
      await pumpToast(
        tester,
        AppTheme.lightTheme,
        (c) => SacSnackBar.show(
          c,
          'listo',
          isSuccess: true,
          leading: const Icon(Icons.info_outline),
        ),
      );
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is HugeIcon), findsNothing);
    });

    for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
      testWidgets(
          'error text and close icon are white (${theme.brightness.name})',
          (tester) async {
        await pumpToast(
          tester,
          theme,
          (c) => SacSnackBar.show(c, 'boom', isError: true),
        );
        final text = tester.widget<Text>(find.text('boom'));
        expect(text.style?.color, Colors.white);
        expect(
          tester.widget<SnackBar>(find.byType(SnackBar)).closeIconColor,
          Colors.white,
        );
      });
    }

    testWidgets('isError and isSuccess are exclusive', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => SacSnackBar.show(
                  context,
                  'x',
                  isError: true,
                  isSuccess: true,
                ),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      expect(tester.takeException(), isA<AssertionError>());
    });

    testWidgets('showMessenger keeps the captured messenger after pop',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () {
                  final messenger = ScaffoldMessenger.of(context);
                  SacSnackBar.showMessenger(messenger, 'ok');
                },
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('go'));
      await tester.pump();

      expect(find.text('ok'), findsOneWidget);
    });

    testWidgets('renders leading and action', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => SacSnackBar.show(
                  context,
                  'undo me',
                  leading: const Icon(Icons.info_outline),
                  action: SnackBarAction(label: 'Undo', onPressed: () {}),
                ),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('go'));
      await tester.pump();

      expect(find.text('undo me'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });

    testWidgets('a toast with an action still auto-dismisses', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => SacSnackBar.show(
                  context,
                  'agregado',
                  duration: const Duration(seconds: 2),
                  action: SnackBarAction(label: 'Ver', onPressed: () {}),
                ),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.text('agregado'), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text('agregado'), findsNothing);
    });
  });
}
