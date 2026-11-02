// Riverpod 3.3.2 pausa los providers que escucha una ruta tapada y los reanuda
// al volver. Si algo los invalidó mientras tanto (o justo al volver), el
// reanudado marca widgets como sucios en mitad de un build y salta la aserción
// de debug "setState() or markNeedsBuild() called during build". Corregido en
// flutter_riverpod 3.4.2+ (pide Flutter 3.44).
//
// Workaround de la app: `MembersView` refresca la lista DESPUÉS del pop y de
// `endOfFrame` (ver `members_view_resume_test.dart` para la ruta real). Aquí se
// reproduce el problema en un arnés mínimo y se fija el patrón que lo evita.
//
// Los dos primeros tests son un tripwire: documentan el bug de 3.3.2. Si fallan
// tras subir Riverpod, el bug se corrigió: se pueden borrar junto con el
// diferido de `MembersView` (`await WidgetsBinding.instance.endOfFrame`).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/riverpod_test_support.dart';

class _Counter extends Notifier<int> {
  static int builds = 0;

  @override
  int build() => ++builds;
}

final _base = NotifierProvider<_Counter, int>(_Counter.new);

/// Derivado: es lo que hace que el reanudado necesite propagar la invalidación.
final _derived = Provider<int>((ref) => ref.watch(_base) * 10);

enum _Invalidate { whileCovered, rightAfterPop, oneFrameAfterPop }

/// Ruta A (observa [_base] y [_derived]) empuja la ruta B; la invalidación
/// ocurre según [when]. Termina con A visible otra vez y todo asentado.
Future<void> _pushPopAndInvalidate(
  WidgetTester tester,
  _Invalidate when,
) async {
  await tester.pumpWidget(
    testProviderScope(
      child: MaterialApp(
        home: Consumer(
          builder: (context, ref, _) => Scaffold(
            body: Column(
              children: [
                Text('A ${ref.watch(_derived)} ${ref.watch(_base)}'),
                TextButton(
                  onPressed: () async {
                    await Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => Consumer(
                          builder: (context, coveringRef, _) => TextButton(
                            onPressed: () {
                              if (when == _Invalidate.whileCovered) {
                                coveringRef.invalidate(_base);
                              }
                              Navigator.pop(context);
                            },
                            child: const Text('B'),
                          ),
                        ),
                      ),
                    );
                    if (when == _Invalidate.oneFrameAfterPop) {
                      await WidgetsBinding.instance.endOfFrame;
                    }
                    if (when != _Invalidate.whileCovered) {
                      ref.invalidate(_base);
                    }
                  },
                  child: const Text('push'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('push'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('B'));
  await tester.pumpAndSettle();
  await tester.pumpAndSettle();
}

Matcher get _setStateDuringBuild => isA<FlutterError>().having(
      (e) => e.toString(),
      'message',
      contains('setState() or markNeedsBuild() called during build'),
    );

void main() {
  setUp(() => _Counter.builds = 0);

  testWidgets('tripwire: invalidating while covered asserts on resume (3.3.2)',
      (tester) async {
    await _pushPopAndInvalidate(tester, _Invalidate.whileCovered);

    expect(tester.takeException(), _setStateDuringBuild);
  });

  testWidgets('tripwire: invalidating right after the pop asserts (3.3.2)',
      (tester) async {
    await _pushPopAndInvalidate(tester, _Invalidate.rightAfterPop);

    expect(tester.takeException(), _setStateDuringBuild);
  });

  testWidgets(
      'invalidating one frame after the pop (MembersView pattern) is safe '
      'and the route refreshes', (tester) async {
    await _pushPopAndInvalidate(tester, _Invalidate.oneFrameAfterPop);

    expect(tester.takeException(), isNull);
    expect(find.text('A 20 2'), findsOneWidget);
    expect(_Counter.builds, 2);
  });
}
