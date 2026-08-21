import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/exceptions.dart';
import 'package:sacdia_app/core/network/network_info.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/profile/domain/entities/user_detail.dart';
import 'package:sacdia_app/features/profile/presentation/providers/profile_providers.dart';
import 'package:sacdia_app/features/qr/domain/entities/qr_member_token.dart';
import 'package:sacdia_app/features/qr/presentation/providers/qr_member_token_provider.dart';
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

class _FakeProfileNotifier extends ProfileNotifier {
  _FakeProfileNotifier(this.profile);

  final UserDetail? profile;

  @override
  Future<UserDetail?> build() async => profile;
}

class _FakeQrMemberTokenNotifier extends QrMemberTokenNotifier {
  _FakeQrMemberTokenNotifier(this.token);

  final QrMemberToken token;

  @override
  Future<QrMemberToken> build() async => token;
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

UserEntity _sampleUser({AuthorizationSnapshot? authorization}) {
  return UserEntity(
    id: 'user-123',
    email: 'ana@example.com',
    name: 'Ana Lopez',
    postRegisterComplete: true,
    authorization: authorization,
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
  UserEntity? user,
  UserDetail? profile,
  QrMemberToken? qrToken,
}) {
  return ProviderContainer(
    overrides: [
      authNotifierProvider.overrideWith(
        () => _FakeAuthNotifier(user ?? _sampleUser()),
      ),
      networkInfoProvider.overrideWithValue(_FakeNetworkInfo(connected)),
      virtualCardRepositoryProvider.overrideWithValue(repository),
      profileNotifierProvider.overrideWith(
        () => _FakeProfileNotifier(profile),
      ),
      qrMemberTokenProvider.overrideWith(
        () => _FakeQrMemberTokenNotifier(
          qrToken ??
              QrMemberToken(
                token: 'qr-token',
                expiresAt: DateTime.utc(2099, 1, 1),
                expiresIn: 300,
              ),
        ),
      ),
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

  test(
    'keeps showing cached card and emits notice when remote is rate limited',
    () async {
      final cached = _sampleCard();
      final repository = _FakeVirtualCardRepository(
        remoteError: ServerException(message: 'Too many requests', code: 429),
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
      expect(container.read(virtualCardRateLimitNoticeProvider), 1);
      expect(repository.remoteCalls, 1);
      expect(repository.cachedCalls, 1);
      expect(repository.saveCalls, 0);
    },
  );

  test(
    'builds offline fallback card with current class and blood type from profile',
    () async {
      final repository = _FakeVirtualCardRepository(
        remoteError: ConnectionException(message: 'offline'),
        cachedCard: null,
      );
      final user = _sampleUser(
        authorization: const AuthorizationSnapshot(
          clubAssignments: [
            AuthorizationGrant(
              assignmentId: 'assignment-1',
              roleName: 'Conquistadores',
              clubTypeName: 'Conquistadores',
            ),
          ],
          activeAssignmentId: 'assignment-1',
        ),
      );
      const profile = UserDetail(
        id: 'user-123',
        email: 'ana@example.com',
        name: 'Ana',
        paternalSurname: 'Lopez',
        clubName: 'Aventuras de Oración',
        currentClass: 'Guía',
        blood: 'O_POSITIVE',
      );
      final container = _buildContainer(
        repository: repository,
        connected: false,
        user: user,
        profile: profile,
      );
      addTearDown(container.dispose);

      final card = await container.read(virtualCardFetcherProvider.future);

      expect(card.sectionName, 'Conquistadores');
      expect(card.currentClass, 'Guía');
      expect(card.bloodType, 'O_POSITIVE');
    },
  );

  test(
    'keeps Guías Mayores on the credential when the active context is Aventureros',
    () async {
      final repository = _FakeVirtualCardRepository(
        remoteError: ConnectionException(message: 'timeout'),
        cachedCard: VirtualCard(
          userId: 'user-123',
          fullName: 'Ana Lopez',
          qrToken: 'token',
          qrExpiresAt: DateTime.utc(2099, 1, 1),
          isActive: true,
          sectionName: 'Aventureros',
        ),
      );
      final user = _sampleUser(
        authorization: const AuthorizationSnapshot(
          clubAssignments: [
            AuthorizationGrant(
              assignmentId: 'av',
              roleName: 'Director',
              clubTypeName: 'Aventureros',
            ),
            AuthorizationGrant(
              assignmentId: 'gm',
              roleName: 'Guía Mayor',
              clubTypeName: 'Guías Mayores',
            ),
          ],
          activeAssignmentId: 'av',
        ),
      );
      final container = _buildContainer(
        repository: repository,
        connected: true,
        user: user,
      );
      addTearDown(container.dispose);

      final card = await container.read(virtualCardFetcherProvider.future);

      expect(card.sectionName, 'Guías Mayores');
      expect(card.isOffline, isTrue);
    },
  );
}
