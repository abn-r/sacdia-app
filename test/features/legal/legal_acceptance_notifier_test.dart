import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/legal/domain/entities/legal_document.dart';
import 'package:sacdia_app/features/legal/domain/entities/legal_status.dart';
import 'package:sacdia_app/features/legal/domain/repositories/legal_repository.dart';
import 'package:sacdia_app/features/legal/presentation/providers/legal_providers.dart';

class _RecordingAuthNotifier extends AuthNotifier {
  int accepted = 0;

  @override
  Future<UserEntity?> build() async => const UserEntity(
        id: 'user-1',
        email: 'user@example.com',
        legalAcceptancePending: true,
      );

  @override
  void markLegalAccepted() => accepted++;
}

class _FakeLegalRepository implements LegalRepository {
  _FakeLegalRepository(this.acceptResult);

  final Either<Failure, LegalStatus> acceptResult;
  int statusCalls = 0;
  ({String terms, String privacy})? sent;

  @override
  Future<Either<Failure, LegalStatus>> accept({
    required String termsVersion,
    required String privacyVersion,
  }) async {
    sent = (terms: termsVersion, privacy: privacyVersion);
    return acceptResult;
  }

  @override
  Future<Either<Failure, LegalStatus>> getMyStatus() async {
    statusCalls++;
    return Right(_status);
  }

  @override
  Future<Either<Failure, List<LegalDocument>>> getCurrentDocuments() async =>
      const Right([]);
}

const _status = LegalStatus(
  requiresAcceptance: true,
  documents: [
    LegalDocumentStatus(
      documentType: LegalDocumentTypes.terms,
      version: '2.0.0',
      url: 'https://sacdia.com/terms',
      accepted: false,
    ),
    LegalDocumentStatus(
      documentType: LegalDocumentTypes.privacy,
      version: '3.0.0',
      url: 'https://sacdia.com/privacy',
      accepted: false,
    ),
  ],
);

({
  ProviderContainer container,
  _RecordingAuthNotifier auth,
  _FakeLegalRepository repo
}) _build(Either<Failure, LegalStatus> acceptResult) {
  final auth = _RecordingAuthNotifier();
  final repo = _FakeLegalRepository(acceptResult);
  final container = ProviderContainer(overrides: [
    authNotifierProvider.overrideWith(() => auth),
    legalRepositoryProvider.overrideWithValue(repo),
  ]);
  addTearDown(container.dispose);
  return (container: container, auth: auth, repo: repo);
}

void main() {
  test('success sends the shown versions and clears the gate', () async {
    final t = _build(const Right(LegalStatus(
      requiresAcceptance: false,
      documents: [],
    )));
    await t.container.read(authNotifierProvider.future);
    t.container.listen(legalAcceptanceNotifierProvider, (_, __) {});

    final ok = await t.container
        .read(legalAcceptanceNotifierProvider.notifier)
        .accept(_status);

    expect(ok, isTrue);
    expect(t.repo.sent, (terms: '2.0.0', privacy: '3.0.0'));
    expect(t.auth.accepted, 1);
    expect(t.container.read(legalAcceptanceNotifierProvider).hasError, isFalse);
  });

  test('LEGAL_VERSION_MISMATCH refetches status and surfaces version_changed',
      () async {
    final t = _build(const Left(ServerFailure(
      message: 'x',
      code: 400,
      errorCode: 'LEGAL_VERSION_MISMATCH',
    )));
    await t.container.read(authNotifierProvider.future);
    t.container.listen(legalAcceptanceNotifierProvider, (_, __) {});
    t.container.listen(myLegalStatusProvider, (_, __) {});
    await t.container.read(myLegalStatusProvider.future);
    expect(t.repo.statusCalls, 1);

    final ok = await t.container
        .read(legalAcceptanceNotifierProvider.notifier)
        .accept(_status);
    await t.container.read(myLegalStatusProvider.future);

    expect(ok, isFalse);
    expect(t.auth.accepted, 0);
    expect(t.repo.statusCalls, 2);
    expect(t.container.read(legalAcceptanceNotifierProvider).error,
        legalVersionChangedKey);
  });

  test('other failures surface accept_error and keep the gate', () async {
    final t = _build(const Left(ServerFailure(message: 'boom', code: 500)));
    await t.container.read(authNotifierProvider.future);
    t.container.listen(legalAcceptanceNotifierProvider, (_, __) {});

    final ok = await t.container
        .read(legalAcceptanceNotifierProvider.notifier)
        .accept(_status);

    expect(ok, isFalse);
    expect(t.auth.accepted, 0);
    expect(t.container.read(legalAcceptanceNotifierProvider).error,
        legalAcceptErrorKey);
  });

  test('a status without both versions never calls the backend', () async {
    final t = _build(Right(_status));
    await t.container.read(authNotifierProvider.future);
    t.container.listen(legalAcceptanceNotifierProvider, (_, __) {});

    final ok = await t.container
        .read(legalAcceptanceNotifierProvider.notifier)
        .accept(const LegalStatus(requiresAcceptance: true, documents: []));

    expect(ok, isFalse);
    expect(t.repo.sent, isNull);
    expect(t.auth.accepted, 0);
  });
}
