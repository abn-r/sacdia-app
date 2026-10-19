import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/features/auth/domain/entities/delete_account_reauth.dart';
import 'package:sacdia_app/features/family/domain/entities/dependent.dart';
import 'package:sacdia_app/features/family/presentation/providers/family_providers.dart';
import 'package:sacdia_app/features/profile/presentation/utils/delete_account_dependents_gate.dart';
import 'package:sacdia_app/features/profile/presentation/utils/delete_account_flow.dart';
import 'package:sacdia_app/features/profile/presentation/widgets/delete_account_dependents_dialog.dart';

import '../family/family_test_harness.dart';

const _ana = DeletionImpactEntry(
  userId: 'ana-1',
  displayName: 'Ana Pérez',
  outcome: DependentOutcome.otherGuardian,
);
const _luis = DeletionImpactEntry(
  userId: 'luis-1',
  displayName: 'Luis Pérez',
  outcome: DependentOutcome.frozen,
);
const _club = DeletionImpactEntry(
  userId: 'eva-1',
  displayName: 'Eva Pérez',
  outcome: DependentOutcome.clubCustody,
);

/// Lleva el resultado de la compuerta a una variable que el test lee.
class _Probe {
  DependentsAck? ack;
  int impactCalls = 0;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initLocalization);

  Future<_Probe> pumpGate(
    WidgetTester tester, {
    required Future<List<DeletionImpactEntry>> Function(_Probe) impact,
    bool refresh = false,
  }) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final probe = _Probe();
    await pumpFamilyApp(
      tester,
      overrides: [
        deletionImpactProvider.overrideWith((ref) {
          probe.impactCalls++;
          return impact(probe);
        }),
      ],
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () async {
                  probe.ack = await confirmDeletionDependents(
                    context,
                    ref,
                    refresh: refresh,
                    timeout: const Duration(milliseconds: 200),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ],
    );
    return probe;
  }

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  SacButton continueButton(WidgetTester tester) =>
      tester.widget<SacButton>(find.widgetWithText(SacButton, 'Continuar'));

  group('confirmDeletionDependents', () {
    testWidgets('lists every outcome and keeps Continue off until ticked',
        (tester) async {
      final probe = await pumpGate(
        tester,
        impact: (_) async => const [_ana, _luis, _club],
      );
      await open(tester);

      expect(find.text('Tienes menores a tu cargo'), findsOneWidget);
      expect(find.text('Otro tutor seguirá a cargo de Ana Pérez.'),
          findsOneWidget);
      expect(
        find.text('El club quedará a cargo de Eva Pérez mientras tanto.'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Luis Pérez quedará congelado y su información se borrará en 90 días.',
        ),
        findsOneWidget,
      );
      expect(continueButton(tester).onPressed, isNull);

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      expect(continueButton(tester).onPressed, isNotNull);

      await tester.tap(find.widgetWithText(SacButton, 'Continuar'));
      await tester.pumpAndSettle();
      expect(probe.ack, DependentsAck.acknowledged);
    });

    testWidgets('ticking and unticking disables Continue again',
        (tester) async {
      await pumpGate(tester, impact: (_) async => const [_ana]);
      await open(tester);

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      expect(continueButton(tester).onPressed, isNull);
    });

    testWidgets('cancelling returns cancelled', (tester) async {
      final probe = await pumpGate(tester, impact: (_) async => const [_ana]);
      await open(tester);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(probe.ack, DependentsAck.cancelled);
    });

    testWidgets('0 dependents: no extra step', (tester) async {
      final probe = await pumpGate(tester, impact: (_) async => const []);
      await open(tester);

      expect(find.text('Tienes menores a tu cargo'), findsNothing);
      expect(probe.ack, DependentsAck.none);
    });

    testWidgets('a failed lookup does not block deletion (server enforces)',
        (tester) async {
      final probe = await pumpGate(
        tester,
        impact: (_) async => throw const ServerFailure(message: 'down'),
      );
      await open(tester);

      expect(find.text('Tienes menores a tu cargo'), findsNothing);
      expect(probe.ack, DependentsAck.none);
    });

    testWidgets('a lookup that never answers times out instead of hanging',
        (tester) async {
      final probe = await pumpGate(
        tester,
        impact: (_) => Future<List<DeletionImpactEntry>>.delayed(
          const Duration(seconds: 30),
          () => const [_ana],
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(probe.ack, DependentsAck.none);
      // Deja correr el temporizador del fake para no dejar timers pendientes.
      await tester.pump(const Duration(seconds: 31));
    });

    testWidgets('refresh re-reads the impact', (tester) async {
      final probe = await pumpGate(
        tester,
        impact: (_) async => const [_ana],
        refresh: true,
      );
      await open(tester);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      await open(tester);

      // Con refresh se invalida el provider: cada apertura vuelve a consultar.
      expect(probe.impactCalls, 2);
    });
  });

  group('DeleteAccountDependentsDialog', () {
    testWidgets('renders one line per dependent', (tester) async {
      await pumpFamilyApp(
        tester,
        overrides: const [],
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const Scaffold(
              body: DeleteAccountDependentsDialog(dependents: [_ana, _luis]),
            ),
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Ana Pérez'), findsOneWidget);
      expect(find.textContaining('Luis Pérez'), findsOneWidget);
    });
  });

  group('DeleteAccountFlow', () {
    const fail409 = DeleteAccountResult(
      errorMessage: 'Confirma qué pasará con los menores',
      errorCode: kDeleteDependentsAckRequiredCode,
    );
    const success = DeleteAccountResult.success();

    ({
      DeleteAccountFlow flow,
      List<DeleteAccountReauth> sent,
      List<bool> confirmRefresh,
      List<int> reauthPrompts,
    }) build({
      required List<DependentsAck> acks,
      required List<DeleteAccountResult> results,
      List<DeleteAccountReauth?>? reauths,
    }) {
      final sent = <DeleteAccountReauth>[];
      final confirmRefresh = <bool>[];
      final reauthPrompts = <int>[];
      var ackIndex = 0;
      var resultIndex = 0;
      var reauthIndex = 0;
      final flow = DeleteAccountFlow(
        confirmDependents: ({required bool refresh}) async {
          confirmRefresh.add(refresh);
          return acks[
              ackIndex++ < acks.length ? ackIndex - 1 : acks.length - 1];
        },
        promptReauth: () async {
          reauthPrompts.add(reauthIndex);
          final list = reauths ?? [const PasswordReauth('pw')];
          return list[reauthIndex++ < list.length ? reauthIndex - 1 : 0];
        },
        delete: (reauth) async {
          sent.add(reauth);
          return results[resultIndex++ < results.length
              ? resultIndex - 1
              : results.length - 1];
        },
      );
      return (
        flow: flow,
        sent: sent,
        confirmRefresh: confirmRefresh,
        reauthPrompts: reauthPrompts,
      );
    }

    test('0 dependents: unchanged flow, no acknowledgement sent', () async {
      final t = build(acks: [DependentsAck.none], results: [success]);

      final result = await t.flow.run();

      expect(result!.isSuccess, isTrue);
      expect(t.sent.single.acknowledgeDependents, isFalse);
      expect(t.confirmRefresh, [false]);
    });

    test('dependents accepted up front: acknowledge_dependents is sent',
        () async {
      final t = build(acks: [DependentsAck.acknowledged], results: [success]);

      await t.flow.run();

      expect(t.sent.single.acknowledgeDependents, isTrue);
      expect(t.sent.single.toBody()['acknowledge_dependents'], isTrue);
    });

    test('cancelling the warning stops before asking for the password',
        () async {
      final t = build(acks: [DependentsAck.cancelled], results: [success]);

      expect(await t.flow.run(), isNull);
      expect(t.reauthPrompts, isEmpty);
      expect(t.sent, isEmpty);
    });

    test('cancelling the password dialog never deletes', () async {
      final t = build(
        acks: [DependentsAck.acknowledged],
        results: [success],
        reauths: [null],
      );

      expect(await t.flow.run(), isNull);
      expect(t.sent, isEmpty);
    });

    test('server 409 re-shows the warning, then retries acknowledged',
        () async {
      final t = build(
        acks: [DependentsAck.none, DependentsAck.acknowledged],
        results: [fail409, success],
      );

      final result = await t.flow.run();

      expect(result!.isSuccess, isTrue);
      expect(t.confirmRefresh, [false, true]);
      expect(t.reauthPrompts.length, 2);
      expect(t.sent.map((r) => r.acknowledgeDependents), [false, true]);
    });

    test('cancelling the warning after a 409 gives up without a second delete',
        () async {
      final t = build(
        acks: [DependentsAck.none, DependentsAck.cancelled],
        results: [fail409],
      );

      expect(await t.flow.run(), isNull);
      expect(t.sent.length, 1);
    });

    test('a 409 with nothing to show surfaces the server message', () async {
      final t = build(
        acks: [DependentsAck.none, DependentsAck.none],
        results: [fail409],
      );

      final result = await t.flow.run();

      expect(result!.errorMessage, 'Confirma qué pasará con los menores');
      expect(t.sent.length, 1);
    });

    test('a server that keeps asking stops after maxAckRetries', () async {
      final t = build(
        acks: [DependentsAck.none, DependentsAck.acknowledged],
        results: [fail409],
      );

      final result = await t.flow.run();

      expect(result!.needsDependentsAck, isTrue);
      // 1 intento + 2 reintentos.
      expect(t.sent.length, 3);
    });

    test('other failures are returned as they are', () async {
      const wrong = DeleteAccountResult(
        errorMessage: 'Contraseña incorrecta',
        errorCode: 'AUTH_INVALID_PASSWORD',
      );
      final t = build(acks: [DependentsAck.none], results: [wrong]);

      final result = await t.flow.run();

      expect(result!.errorMessage, 'Contraseña incorrecta');
      expect(t.sent.length, 1);
    });
  });
}
