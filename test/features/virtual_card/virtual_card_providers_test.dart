import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/exceptions.dart';
import 'package:sacdia_app/core/network/network_info.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/virtual_card/domain/entities/virtual_card.dart';
import 'package:sacdia_app/features/virtual_card/domain/repositories/virtual_card_repository.dart';
import 'package:sacdia_app/features/virtual_card/presentation/providers/virtual_card_providers.dart';

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(this.user);

  final UserEntity? user;

  @override
  Future<UserEntity?> build() async => user;
}

class _FakeNetworkInfo implements NetworkInfo {
  _FakeNetworkInfo(this.connected);

  final bool connected;

  @override
  Future<bool> get isConnected async => connected;
}

class _FakeVirtualCardRepository implements VirtualCardRepository {
  _FakeVirtualCardRepository({
    required this.remoteError,
    required this.cachedCard,
  });

  final Object? remoteError;
  final VirtualCard? cachedCard;

  int remoteCalls = 0;
  int cachedCalls = 0;
  int saveCalls = 0;

  @override
  Future<VirtualCard> getRemoteCard() async {
    remoteCalls++;
    if (remoteError != null) {
      throw remoteError!;
    }
    throw StateError('Expected remoteError to be provided in this test');
  }

  @override
  Future<VirtualCard?> getCachedCard(String userId) async {
    cachedCalls++;
    return cachedCard;
  }

  @override
  Future<void> saveCachedCard(VirtualCard card) async {
    saveCalls++;
  }
}

UserEntity _sampleUser() {
  return const UserEntity(
    id: 'user-123',
    email: 'ana@example.com',
    name: 'Ana Lopez',
    postRegisterComplete: true,
  );
}

VirtualCard _sampleCard({bool isOffline = false}) {
  return VirtualCard(
    userId: 'user-123',
    fullName: 'Ana Lopez',
    qrToken: 'token',
    qrExpiresAt: DateTime.utc(2099, 1, 1),
    isActive: true,
    isOffline: isOffline,
  );
}

ProviderContainer _buildContainer({
  required VirtualCardRepository repository,
  required bool connected,
}) {
  return ProviderContainer(
    overrides: [
      authNotifierProvider.overrideWith(() => _FakeAuthNotifier(_sampleUser())),
      networkInfoProvider.overrideWithValue(_FakeNetworkInfo(connected)),
      virtualCardRepositoryProvider.overrideWithValue(repository),
    ],
  );
}

void main() {
  test(
    'falls back to cached card when the remote call fails with connectivity errors',
    () async {
      final cached = _sampleCard();
      final repository = _FakeVirtualCardRepository(
        remoteError: ConnectionException(message: 'timeout'),
        cachedCard: cached,
      );
      final container = _buildContainer(
        repository: repository,
        connected: true,
      );
      addTearDown(container.dispose);

      final card = await container.read(virtualCardFetcherProvider.future);

      expect(card.userId, cached.userId);
      expect(card.isOffline, isTrue);
      expect(repository.remoteCalls, 1);
      expect(repository.cachedCalls, 1);
      expect(repository.saveCalls, 0);
    },
  );

  test(
    'surfaces functional server errors instead of hiding them behind fallback',
    () async {
      final repository = _FakeVirtualCardRepository(
        remoteError: ServerException(message: 'Forbidden', code: 403),
        cachedCard: _sampleCard(),
      );
      final container = _buildContainer(
        repository: repository,
        connected: true,
      );
      addTearDown(container.dispose);

      await expectLater(
        container.read(virtualCardFetcherProvider.future),
        throwsA(
          isA<ServerException>().having((e) => e.code, 'code', 403),
        ),
      );

      expect(repository.remoteCalls, 1);
      expect(repository.cachedCalls, 1);
      expect(repository.saveCalls, 0);
    },
  );
}
