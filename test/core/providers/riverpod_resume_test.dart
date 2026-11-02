// Riverpod pausa los providers que escucha una ruta tapada y los reanuda al
// volver. En 3.3.2, si algo los invalidaba mientras tanto (o justo al volver),
// el reanudado marcaba widgets como sucios en mitad de un build y saltaba la
// aserción de debug "setState() or markNeedsBuild() called during build"
// (corregido en flutter_riverpod 3.4.2). Estos tests fijan que ninguno de los
// tres momentos de invalidar vuelve a romper si una versión futura lo
// reintroduce. La ruta real está en `members_view_resume_test.dart`.
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

void main() {
  setUp(() => _Counter.builds = 0);

  for (final when in _Invalidate.values) {
    testWidgets(
        'invalidating ${when.name} resumes without a build-phase '
        'error and the route refreshes', (tester) async {
      await _pushPopAndInvalidate(tester, when);

      expect(tester.takeException(), isNull);
      expect(find.text('A 20 2'), findsOneWidget);
      expect(_Counter.builds, 2);
    });
  }
}
