import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_dialog.dart';

void main() {
  testWidgets('normal dialog enters from the shared scale over modal duration',
      (
    tester,
  ) async {
    final reduceMotion = ValueNotifier<bool>(false);
    addTearDown(reduceMotion.dispose);

    await tester.pumpWidget(
      _DialogHarness(reduceMotion: reduceMotion),
    );

    expect(_scale(tester).scale.value, SacMotion.enterScale);
    expect(_fade(tester).opacity.value, 0);

    await tester.pump(SacMotion.modal ~/ 2);
    expect(_scale(tester).scale.value, inExclusiveRange(0.96, 1));
    expect(_fade(tester).opacity.value, inExclusiveRange(0, 1));

    await tester.pump(SacMotion.modal ~/ 2);
    expect(_scale(tester).scale.value, 1);
    expect(_fade(tester).opacity.value, 1);
  });

  testWidgets('runtime reduced motion toggle removes scale and keeps fade', (
    tester,
  ) async {
    final reduceMotion = ValueNotifier<bool>(false);
    addTearDown(reduceMotion.dispose);

    await tester.pumpWidget(
      _DialogHarness(reduceMotion: reduceMotion),
    );
    await tester.pump(const Duration(milliseconds: 40));

    reduceMotion.value = true;
    await tester.pump();

    expect(find.byKey(const ValueKey('sac_dialog_scale')), findsNothing);
    expect(find.byKey(const ValueKey('sac_dialog_fade')), findsOneWidget);

    await tester.pump(SacMotion.reducedFade);
    expect(_fade(tester).opacity.value, 1);
  });

  testWidgets(
      're-enabling motion during initially reduced entrance keeps scale stable',
      (
    tester,
  ) async {
    final reduceMotion = ValueNotifier<bool>(true);
    addTearDown(reduceMotion.dispose);

    await tester.pumpWidget(
      _DialogHarness(reduceMotion: reduceMotion),
    );
    await tester.pump(const Duration(milliseconds: 40));
    expect(_fade(tester).opacity.value, inExclusiveRange(0, 1));
    expect(_dialogScaleValue(tester), 1);

    reduceMotion.value = false;
    await tester.pump();

    expect(_dialogScaleValue(tester), 1);
  });

  testWidgets(
      're-enabling motion after suppression never restores partial scale', (
    tester,
  ) async {
    final reduceMotion = ValueNotifier<bool>(false);
    addTearDown(reduceMotion.dispose);

    await tester.pumpWidget(
      _DialogHarness(reduceMotion: reduceMotion),
    );
    await tester.pump(const Duration(milliseconds: 40));
    expect(_dialogScaleValue(tester), lessThan(1));

    reduceMotion.value = true;
    await tester.pump(const Duration(milliseconds: 20));
    expect(_fade(tester).opacity.value, inExclusiveRange(0, 1));
    expect(_dialogScaleValue(tester), 1);

    reduceMotion.value = false;
    await tester.pump();

    expect(_dialogScaleValue(tester), 1);
  });

  testWidgets(
      'should use SacButton for dialog actions instead of Material buttons',
      (tester) async {
    var confirmed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SacDialog(
            title: 'Dialog',
            actions: [
              SacDialogAction(
                label: 'Cancelar',
                style: SacDialogActionStyle.cancel,
                onPressed: () {},
              ),
              SacDialogAction(
                label: 'Confirmar',
                onPressed: () => confirmed = true,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(SacButton), findsNWidgets(2));
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(TextButton), findsNothing);

    await tester.tap(find.text('Confirmar'));
    expect(confirmed, isTrue);
  });

  testWidgets('renders optional body below content', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SacDialog(
            title: 'Dialog',
            content: 'Hello',
            body: Text('Field body'),
            actions: [
              SacDialogAction(label: 'OK', onPressed: null),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Hello'), findsOneWidget);
    expect(find.text('Field body'), findsOneWidget);
  });
}

FadeTransition _fade(WidgetTester tester) => tester.widget<FadeTransition>(
      find.byKey(const ValueKey('sac_dialog_fade')),
    );

ScaleTransition _scale(WidgetTester tester) => tester.widget<ScaleTransition>(
      find.byKey(const ValueKey('sac_dialog_scale')),
    );

double _dialogScaleValue(WidgetTester tester) {
  final scaleTransition = find.byKey(const ValueKey('sac_dialog_scale'));
  if (scaleTransition.evaluate().isEmpty) return 1;
  return tester.widget<ScaleTransition>(scaleTransition).scale.value;
}

class _DialogHarness extends StatelessWidget {
  const _DialogHarness({required this.reduceMotion});

  final ValueListenable<bool> reduceMotion;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: reduceMotion,
      builder: (context, disabled, _) => MediaQuery(
        data: MediaQueryData(disableAnimations: disabled),
        child: MaterialApp(
          home: Scaffold(
            body: SacDialog(
              title: 'Dialog',
              actions: [
                SacDialogAction(label: 'OK', onPressed: () {}),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
