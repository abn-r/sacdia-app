import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/master_honors/presentation/providers/master_honor_modal_queue_provider.dart';
import 'package:sacdia_app/features/master_honors/presentation/widgets/master_honor_change_modal.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      home: Scaffold(body: child),
    );
  }

  testWidgets('renders awarded singular copy', (tester) async {
    await tester.pumpWidget(
      wrap(
        MasterHonorChangeModal(
          event: MasterHonorModalEvent(
            transition: MasterHonorChangeTransition.awarded,
            masterHonorIds: const ['1'],
            masterHonorNames: const ['Maestría en Acuática'],
          ),
        ),
      ),
    );

    expect(find.text('¡Nueva maestría obtenida!'), findsOneWidget);
    expect(
      find.text('Has obtenido la maestría Maestría en Acuática.'),
      findsOneWidget,
    );
  });

  testWidgets('renders not current plural copy with grouped names',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        MasterHonorChangeModal(
          event: MasterHonorModalEvent(
            transition: MasterHonorChangeTransition.notCurrent,
            masterHonorIds: const ['1', '2'],
            masterHonorNames: const [
              'Maestría en Acuática',
              'Maestría en Artesanía',
            ],
          ),
        ),
      ),
    );

    expect(find.text('Maestrías marcadas como No vigente'), findsOneWidget);
    expect(
      find.text(
        'Las validaciones requeridas para estas maestrías cambiaron. Actualmente no cumples con los requisitos, por lo que quedaron marcadas como No vigente.',
      ),
      findsOneWidget,
    );
    expect(find.text('Maestría en Acuática'), findsOneWidget);
    expect(find.text('Maestría en Artesanía'), findsOneWidget);
  });

  test('master honor modal queue removes current event before continuing', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(masterHonorModalQueueProvider.notifier);

    notifier.enqueue(
      const MasterHonorModalEvent(
        transition: MasterHonorChangeTransition.notCurrent,
        masterHonorIds: ['1'],
        masterHonorNames: ['Maestría en Acuática'],
      ),
    );
    notifier.enqueue(
      const MasterHonorModalEvent(
        transition: MasterHonorChangeTransition.recovered,
        masterHonorIds: ['2'],
        masterHonorNames: ['Maestría en Artesanía'],
      ),
    );

    notifier.markModalStarted();
    notifier.removeFirst();
    notifier.markModalFinished();

    final state = container.read(masterHonorModalQueueProvider);
    expect(state.isShowingModal, isFalse);
    expect(state.length, 1);
    expect(state.single.transition, MasterHonorChangeTransition.recovered);
  });
}
