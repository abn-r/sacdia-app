import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/widgets/dismiss_keyboard_on_tap_outside.dart';
import 'package:sacdia_app/core/widgets/sac_sheet.dart';

void main() {
  group('DismissKeyboardOnTapOutside', () {
    testWidgets('tapping outside the focused field removes its focus',
        (tester) async {
      final focus = await _pumpForm(tester);

      await tester.tap(find.byKey(const Key('field')));
      await tester.pump();
      expect(focus.hasFocus, isTrue);

      await tester.tapAt(const Offset(200, 500));
      await tester.pump();
      expect(focus.hasFocus, isFalse);
    });

    testWidgets('without the wrapper a touch outside keeps the focus',
        (tester) async {
      // Guards the reason this widget exists: Flutter keeps the field focused
      // on Android and iOS touches.
      final focus = await _pumpForm(tester, wrap: false);

      await tester.tap(find.byKey(const Key('field')));
      await tester.pump();
      await tester.tapAt(const Offset(200, 500));
      await tester.pump();

      expect(focus.hasFocus, isTrue);
    });

    testWidgets('scrolling outside the field keeps the keyboard open',
        (tester) async {
      final focus = await _pumpForm(tester);

      await tester.tap(find.byKey(const Key('field')));
      await tester.pump();
      await tester.dragFrom(const Offset(200, 500), const Offset(0, -120));
      await tester.pump();

      expect(focus.hasFocus, isTrue);
    });

    testWidgets('tapping a TextFieldTapRegion keeps the focus', (tester) async {
      var pressed = false;
      final focus = await _pumpForm(
        tester,
        accessory: TextFieldTapRegion(
          child: TextButton(
            key: const Key('accessory'),
            onPressed: () => pressed = true,
            child: const Text('Siguiente'),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('field')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('accessory')));
      await tester.pump();

      expect(pressed, isTrue);
      expect(focus.hasFocus, isTrue);
    });

    testWidgets('a button outside the field still fires after unfocusing',
        (tester) async {
      var pressed = false;
      final focus = await _pumpForm(
        tester,
        accessory: TextButton(
          key: const Key('accessory'),
          onPressed: () => pressed = true,
          child: const Text('Guardar'),
        ),
      );

      await tester.tap(find.byKey(const Key('field')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('accessory')));
      await tester.pump();

      expect(pressed, isTrue);
      expect(focus.hasFocus, isFalse);
    });

    testWidgets(
        'tapping a sheet outside its field unfocuses, the barrier '
        'closes the sheet', (tester) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) =>
              DismissKeyboardOnTapOutside(child: child!),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showSacSheet<void>(
                    context: context,
                    builder: (_) => SizedBox(
                      height: 300,
                      width: double.infinity,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            TextField(
                              key: const Key('sheet-field'),
                              focusNode: focus,
                            ),
                            const Spacer(),
                            const Text('Cuerpo de la hoja'),
                          ],
                        ),
                      ),
                    ),
                  ),
                  child: const Text('Abrir'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('sheet-field')));
      await tester.pump();
      expect(focus.hasFocus, isTrue);

      // Inside the sheet but outside the field: keyboard closes, sheet stays.
      await tester.tap(find.text('Cuerpo de la hoja'));
      await tester.pumpAndSettle();
      expect(focus.hasFocus, isFalse);
      expect(find.byKey(const Key('sheet-field')), findsOneWidget);

      // On the barrier above the sheet: showSacSheet is dismissible by
      // default.
      await tester.tapAt(const Offset(200, 40));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('sheet-field')), findsNothing);
    });
  });
}

Future<FocusNode> _pumpForm(
  WidgetTester tester, {
  bool wrap = true,
  Widget? accessory,
}) async {
  final focus = FocusNode();
  addTearDown(focus.dispose);

  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) =>
          wrap ? DismissKeyboardOnTapOutside(child: child!) : child!,
      home: Scaffold(
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(key: const Key('field'), focusNode: focus),
            if (accessory != null) accessory,
            const SizedBox(height: 1200),
          ],
        ),
      ),
    ),
  );
  return focus;
}
