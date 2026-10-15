import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
}

class _FakeLegalRepository implements LegalRepository {
  /// Each call to [getMyStatus] consumes the next entry (the last one repeats).
  List<Either<Failure, LegalStatus>> statusQueue = [Right(_status())];
  Either<Failure, LegalStatus> acceptResult = Right(_status());
  int statusCalls = 0;
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
  _FakeLegalRepository repo,
) async {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final auth = _RecordingAuthNotifier();
  final opened = <Uri>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authNotifierProvider.overrideWith(() => auth),
        legalRepositoryProvider.overrideWithValue(repo),
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
}
