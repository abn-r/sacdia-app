import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/auth/acting_for_session.dart';
import 'package:sacdia_app/core/network/network_info.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/virtual_card/data/datasources/virtual_card_remote_data_source.dart';
import 'package:sacdia_app/features/virtual_card/data/models/virtual_card_model.dart';
import 'package:sacdia_app/features/virtual_card/data/repositories/virtual_card_repository_impl.dart';
import 'package:sacdia_app/features/virtual_card/domain/entities/virtual_card.dart';
import 'package:sacdia_app/features/virtual_card/domain/repositories/virtual_card_repository.dart';
import 'package:sacdia_app/features/virtual_card/presentation/providers/virtual_card_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../support/riverpod_test_support.dart';

/// C1 (verify 2b): la credencial de un dependiente nunca se persiste en disco
/// (FP-49, FP-51, FP-53). Usa el repositorio REAL con SharedPreferences
/// simulado, porque el fallo estaba justo en lo que escribe ese repositorio.

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(this.user);

  final UserEntity user;

  @override
  Future<UserEntity?> build() async => user;
}

class _Online implements NetworkInfo {
  @override
  Future<bool> get isConnected async => true;
}

class _SpyRepository extends VirtualCardRepositoryImpl {
  _SpyRepository(VirtualCardRemoteDataSource remote)
      : super(remoteDataSource: remote, networkInfo: _Online());

  int cachedReads = 0;

  @override
  Future<VirtualCard?> getCachedCard(String userId) {
    cachedReads++;
    return super.getCachedCard(userId);
  }
}

class _FakeRemote implements VirtualCardRemoteDataSource {
  _FakeRemote(this.userId);

  final String userId;
  int calls = 0;

  /// Si se da, la respuesta espera a que se complete (petición "en vuelo").
  Completer<void>? gate;

  @override
  Future<VirtualCardModel> getVirtualCard({CancelToken? cancelToken}) async {
    calls++;
    await gate?.future;
    return VirtualCardModel(
      userId: userId,
      fullName: 'Nombre de $userId',
      qrToken: 'qr-$userId',
      qrExpiresAt: DateTime.utc(2099, 1, 1),
      isActive: true,
    );
  }
}

UserEntity _user(String id) => UserEntity(
      id: id,
      email: id == 'guardian-1' ? 'maria@example.com' : null,
      name: id,
      postRegisterComplete: true,
    );

Set<String> _cardKeys(SharedPreferences prefs) =>
    prefs.getKeys().where((k) => k.startsWith('virtual_card_cache_')).toSet();

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  ProviderContainer build({
    required String userId,
    required ActingForSession session,
    required _FakeRemote remote,
    VirtualCardRepository? repository,
  }) {
    final container = createTestContainer(
      overrides: [
        authNotifierProvider
            .overrideWith(() => _FakeAuthNotifier(_user(userId))),
        networkInfoProvider.overrideWithValue(_Online()),
        actingForSessionProvider.overrideWithValue(session),
        virtualCardRemoteDataSourceProvider.overrideWithValue(remote),
        if (repository != null)
          virtualCardRepositoryProvider.overrideWithValue(repository),
      ],
    );
    return container;
  }

  test('acting for a dependent never writes the card to SharedPreferences',
      () async {
    final session = ActingForSession()
      ..enter(const ActingDependent(userId: 'ana-1', firstName: 'Ana'));
    final remote = _FakeRemote('ana-1');
    final container = build(userId: 'ana-1', session: session, remote: remote);

    final card = await container.read(virtualCardFetcherProvider.future);

    expect(card.userId, 'ana-1', reason: 'the card is still shown');
    expect(remote.calls, 1);
    expect(_cardKeys(prefs), isEmpty);
    expect(
      prefs.getKeys().map(prefs.get).whereType<String>(),
      everyElement(isNot(contains('ana-1'))),
      reason: 'no stored value carries the dependent PII or QR token',
    );
  });

  test('acting never READS a cached card either', () async {
    await prefs.setString(
      'virtual_card_cache_ana-1',
      '{"user_id":"ana-1","full_name":"Stale Ana","qr_token":"old",'
          '"qr_expires_at":"2099-01-01T00:00:00.000Z","is_active":true}',
    );
    final session = ActingForSession()
      ..enter(const ActingDependent(userId: 'ana-1'));
    final remote = _FakeRemote('ana-1');
    final repository = _SpyRepository(remote);
    final container = build(
      userId: 'ana-1',
      session: session,
      remote: remote,
      repository: repository,
    );

    await container.read(virtualCardFetcherProvider.future);

    expect(repository.cachedReads, 0);
  });

  test(
      'the dependent card is not persisted when the profile is left '
      'while the request is in flight', () async {
    final session = ActingForSession()
      ..enter(const ActingDependent(userId: 'ana-1'));
    final remote = _FakeRemote('ana-1')..gate = Completer<void>();
    final container = build(userId: 'ana-1', session: session, remote: remote);

    final pending = container.read(virtualCardFetcherProvider.future);
    await pumpEventQueue();
    expect(remote.calls, 1, reason: 'the request is in flight');
    session.exit(); // el tutor vuelve a su perfil antes de la respuesta
    remote.gate!.complete();
    await pending;

    expect(_cardKeys(prefs), isEmpty);
  });

  test(
      'S1: a switch to a dependent while the guardian request is in flight '
      'drops the save (re-check right before saveCachedCard)', () async {
    final session = ActingForSession();
    // La petición sale como tutor; el servidor responde con la tarjeta de Ana
    // porque el cambio de perfil llegó antes de la respuesta.
    final remote = _FakeRemote('ana-1')..gate = Completer<void>();
    final container =
        build(userId: 'guardian-1', session: session, remote: remote);

    final pending = container.read(virtualCardFetcherProvider.future);
    await pumpEventQueue();
    expect(remote.calls, 1, reason: 'the request is in flight');
    session.enter(const ActingDependent(userId: 'ana-1', firstName: 'Ana'));
    remote.gate!.complete();
    await pending;

    expect(_cardKeys(prefs), isEmpty);
  });

  test(
      'S1: a guardian -> dependent -> guardian round trip during the request '
      'also drops the save (generation changed)', () async {
    final session = ActingForSession();
    final remote = _FakeRemote('guardian-1')..gate = Completer<void>();
    final container =
        build(userId: 'guardian-1', session: session, remote: remote);

    final pending = container.read(virtualCardFetcherProvider.future);
    await pumpEventQueue();
    session
      ..enter(const ActingDependent(userId: 'ana-1'))
      ..exit();
    remote.gate!.complete();
    await pending;

    expect(_cardKeys(prefs), isEmpty);
  });

  test('the guardian own card is still cached for offline use', () async {
    final session = ActingForSession();
    final remote = _FakeRemote('guardian-1');
    final container =
        build(userId: 'guardian-1', session: session, remote: remote);

    await container.read(virtualCardFetcherProvider.future);

    expect(_cardKeys(prefs), {'virtual_card_cache_guardian-1'});
  });
}
