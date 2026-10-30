import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/auth/acting_for_session.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/legal/domain/entities/legal_document.dart';
import 'package:sacdia_app/features/legal/domain/entities/legal_status.dart';
import 'package:sacdia_app/features/legal/domain/repositories/legal_repository.dart';
import 'package:sacdia_app/features/legal/presentation/providers/legal_providers.dart';
import 'package:sacdia_app/features/legal/presentation/views/legal_acceptance_view.dart';
import '../../../support/riverpod_test_support.dart';

LegalStatus _status({
  String terms = '1.0.0',
  String privacy = '1.0.0',
  bool requiresAcceptance = true,
}) =>
    LegalStatus(
      requiresAcceptance: requiresAcceptance,
      documents: [
        LegalDocumentStatus(
          documentType: LegalDocumentTypes.terms,
          version: terms,
          url: 'https://sacdia.com/terms',
          accepted: !requiresAcceptance,
        ),
        LegalDocumentStatus(
          documentType: LegalDocumentTypes.privacy,
          version: privacy,
          url: 'https://sacdia.com/privacy',
          accepted: !requiresAcceptance,
        ),
      ],
    );

class _RecordingAuthNotifier extends AuthNotifier {
  int accepted = 0;
  int signedOut = 0;
  final switched = <String?>[];

  @override
  Future<UserEntity?> build() async => const UserEntity(
        id: 'user-1',
        email: 'user@example.com',
        legalAcceptancePending: true,
      );

  @override
  void markLegalAccepted() => accepted++;

  @override
  Future<bool> signOut() async {
    signedOut++;
    return true;
  }

  @override
  Future<SwitchProfileOutcome> switchProfile(
    String? dependentUserId, {
    String? firstName,
  }) async {
    switched.add(dependentUserId);
    return SwitchProfileOutcome.exited;
  }
}

class _FakeLegalRepository implements LegalRepository {
  /// Each call to [getMyStatus] consumes the next entry (the last one repeats).
  List<Either<Failure, LegalStatus>> statusQueue = [Right(_status())];
  Either<Failure, LegalStatus> acceptResult = Right(_status());
  int statusCalls = 0;

  /// When set, [accept] stays pending until it completes (in-flight state).
  Completer<void>? acceptGate;
  final List<({String terms, String privacy})> sent = [];

  @override
  Future<Either<Failure, LegalStatus>> getMyStatus() async {
    final i =
        statusCalls < statusQueue.length ? statusCalls : statusQueue.length - 1;
    statusCalls++;
    return statusQueue[i];
  }

  @override
  Future<Either<Failure, LegalStatus>> accept({
    required String termsVersion,
    required String privacyVersion,
  }) async {
    sent.add((terms: termsVersion, privacy: privacyVersion));
    await acceptGate?.future;
    return acceptResult;
  }

  @override
  Future<Either<Failure, List<LegalDocument>>> getCurrentDocuments() async =>
      const Right([]);
}

class _Harness {
  _Harness(this.auth, this.repo, this.opened);
  final _RecordingAuthNotifier auth;
  final _FakeLegalRepository repo;
  final List<Uri> opened;
}

Future<_Harness> _pump(
  WidgetTester tester,
  _FakeLegalRepository repo, {
  ActingForSession? session,
}) async {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final auth = _RecordingAuthNotifier();
  final opened = <Uri>[];
  await tester.pumpWidget(
    testProviderScope(
      overrides: [
        authNotifierProvider.overrideWith(() => auth),
        legalRepositoryProvider.overrideWithValue(repo),
        if (session != null)
          actingForSessionProvider.overrideWithValue(session),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        // Without translations loaded, labels are raw (long) keys rendered in
        // the wide Ahem test font; scale text down so layout matches real copy.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(0.5),
          ),
          child: child!,
        ),
        home: LegalAcceptanceView(
          onOpenDocument: (uri) async {
            opened.add(uri);
            return true;
          },
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return _Harness(auth, repo, opened);
}

Finder get _acceptFinder =>
    find.widgetWithText(SacButton, 'legal_gate.accept_button');

SacButton _acceptButton(WidgetTester tester) =>
    tester.widget<SacButton>(_acceptFinder);

// While submitting the button shows a spinner instead of its label, so it is
// located by widget type + text field rather than by rendered text.
Finder get _acceptByWidget => find.byWidgetPredicate(
      (w) => w is SacButton && w.text == 'legal_gate.accept_button',
    );

/// Accept-button label texts that are actually painted (excludes the
/// zero-opacity copy that only reserves the button width while loading).
int _visibleAcceptLabels(WidgetTester tester) {
  final label = find.descendant(
    of: _acceptByWidget,
    matching: find.text('legal_gate.accept_button'),
  );
  final hidden = find.descendant(
    of: find.byWidgetPredicate((w) => w is Opacity && w.opacity == 0),
    matching: label,
  );
  return label.evaluate().length - hidden.evaluate().length;
}

void main() {
  testWidgets('is a blocking route (PopScope canPop false)', (tester) async {
    await _pump(tester, _FakeLegalRepository());

    final pop = tester.widget<PopScope>(find.byType(PopScope));
    expect(pop.canPop, isFalse);
  });

  testWidgets('accept stays disabled until the checkbox is checked',
      (tester) async {
    await _pump(tester, _FakeLegalRepository());

    expect(find.text('legal_gate.document_terms'), findsOneWidget);
    expect(find.text('legal_gate.document_privacy'), findsOneWidget);
    expect(_acceptButton(tester).isEnabled, isFalse);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();

    expect(_acceptButton(tester).isEnabled, isTrue);
  });

  testWidgets('accepting sends the shown versions and clears the gate',
      (tester) async {
    final repo = _FakeLegalRepository()
      ..statusQueue = [Right(_status(terms: '2.0.0', privacy: '3.0.0'))]
      ..acceptResult = Right(_status(requiresAcceptance: false));
    final h = await _pump(tester, repo);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    _acceptButton(tester).onPressed!();
    await tester.pump();
    await tester.pump();

    expect(h.repo.sent, [(terms: '2.0.0', privacy: '3.0.0')]);
    expect(h.auth.accepted, 1);
  });

  testWidgets('read links open the document url', (tester) async {
    final h = await _pump(tester, _FakeLegalRepository());

    await tester.tap(find.text('legal_gate.read_document').first);
    await tester.pump();

    expect(h.opened, [Uri.parse('https://sacdia.com/terms')]);
  });

  testWidgets('sign out is always available and signs out', (tester) async {
    final h = await _pump(tester, _FakeLegalRepository());

    await tester.tap(find.text('legal_gate.sign_out'));
    await tester.pump();

    expect(h.auth.signedOut, 1);
  });

  testWidgets('load error shows retry and sign out; retry refetches',
      (tester) async {
    final repo = _FakeLegalRepository()
      ..statusQueue = [
        const Left(ServerFailure(message: 'down', code: 500)),
        Right(_status()),
      ];
    final h = await _pump(tester, repo);

    expect(find.text('legal_gate.load_error'), findsOneWidget);
    expect(find.text('legal_gate.sign_out'), findsOneWidget);
    expect(_acceptFinder, findsNothing);

    await tester.tap(find.text('legal_gate.retry'));
    await tester.pump();
    await tester.pump();

    expect(h.repo.statusCalls, 2);
    expect(find.text('legal_gate.load_error'), findsNothing);
    expect(_acceptFinder, findsOneWidget);
  });

  testWidgets('self-heals when the backend no longer requires acceptance',
      (tester) async {
    final repo = _FakeLegalRepository()
      ..statusQueue = [Right(_status(requiresAcceptance: false))];
    final h = await _pump(tester, repo);
    await tester.pump();

    expect(h.auth.accepted, 1);
  });

  testWidgets('version mismatch refetches, resets the checkbox and warns',
      (tester) async {
    final repo = _FakeLegalRepository()
      ..statusQueue = [
        Right(_status(terms: '1.0.0', privacy: '1.0.0')),
        Right(_status(terms: '2.0.0', privacy: '1.0.0')),
      ]
      ..acceptResult = const Left(ServerFailure(
        message: 'x',
        code: 400,
        errorCode: 'LEGAL_VERSION_MISMATCH',
      ));
    final h = await _pump(tester, repo);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    _acceptButton(tester).onPressed!();
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(h.auth.accepted, 0);
    expect(h.repo.statusCalls, 2);
    expect(find.text('legal_gate.version_changed'), findsOneWidget);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
    expect(_acceptButton(tester).isEnabled, isFalse);
  });

  testWidgets('other accept failures show accept_error and keep the gate',
      (tester) async {
    final repo = _FakeLegalRepository()
      ..acceptResult = const Left(ServerFailure(message: 'boom', code: 500));
    final h = await _pump(tester, repo);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    _acceptButton(tester).onPressed!();
    await tester.pump();
    await tester.pump();

    expect(h.auth.accepted, 0);
    expect(find.text('legal_gate.accept_error'), findsOneWidget);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
  });

  testWidgets('while accept is in flight the form is locked until it resolves',
      (tester) async {
    final gate = Completer<void>();
    final repo = _FakeLegalRepository()
      ..acceptGate = gate
      ..acceptResult = Right(_status(requiresAcceptance: false));
    final h = await _pump(tester, repo);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(tester.widget<SacButton>(_acceptByWidget).isEnabled, isTrue);

    tester.widget<SacButton>(_acceptByWidget).onPressed!();
    await tester.pump();
    await tester.pump();

    // In flight: request sent, nothing resolved yet.
    expect(h.repo.sent, hasLength(1));
    expect(h.auth.accepted, 0);
    final inFlight = tester.widget<SacButton>(_acceptByWidget);
    expect(inFlight.isEnabled, isFalse);
    expect(inFlight.isLoading, isTrue);
    expect(inFlight.onPressed, isNull);
    final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
    expect(checkbox.onChanged, isNull);

    // A second tap while in flight must not send a second request.
    await tester.tap(find.byType(Checkbox), warnIfMissed: false);
    await tester.pump();
    expect(h.repo.sent, hasLength(1));

    gate.complete();
    await tester.pump();
    await tester.pump();

    expect(h.repo.sent, hasLength(1));
    expect(h.auth.accepted, 1);
  });

  testWidgets('while accept is in flight the spinner replaces the label',
      (tester) async {
    final gate = Completer<void>();
    final repo = _FakeLegalRepository()
      ..acceptGate = gate
      ..acceptResult = Right(_status(requiresAcceptance: false));
    await _pump(tester, repo);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(_visibleAcceptLabels(tester), 1);

    tester.widget<SacButton>(_acceptByWidget).onPressed!();
    // Mid cross-fade: the outgoing label must not stay painted under the spinner.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));

    expect(_visibleAcceptLabels(tester), 0);
    expect(
      find.descendant(
        of: _acceptByWidget,
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 1));
    expect(_visibleAcceptLabels(tester), 0);

    gate.complete();
    await tester.pump();
    await tester.pump();
  });

  group('while acting for a dependent (S4)', () {
    ActingForSession acting() => ActingForSession()
      ..enter(const ActingDependent(userId: 'ana-1', firstName: 'Ana'));

    testWidgets(
        'offers "back to my profile" instead of signing the guardian out',
        (tester) async {
      await _pump(tester, _FakeLegalRepository(), session: acting());

      expect(find.text('legal_gate.sign_out'), findsNothing);
      expect(find.text('family.banner.back'), findsOneWidget);
    });

    testWidgets(
        'the exit button leaves the dependent profile and never '
        'signs out', (tester) async {
      final h = await _pump(tester, _FakeLegalRepository(), session: acting());

      await tester.tap(find.text('family.banner.back'));
      await tester.pump();

      expect(h.auth.switched, [null]);
      expect(h.auth.signedOut, 0);
    });

    testWidgets('outside acting the sign out button is unchanged',
        (tester) async {
      await _pump(tester, _FakeLegalRepository());

      expect(find.text('legal_gate.sign_out'), findsOneWidget);
      expect(find.text('family.banner.back'), findsNothing);
    });
  });
}
