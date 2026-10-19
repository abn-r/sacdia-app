import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/acting_for_session.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/dio_client.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../profile/domain/entities/user_detail.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../qr/domain/entities/qr_member_token.dart';
import '../../../qr/presentation/providers/qr_member_token_provider.dart';
import '../../data/datasources/virtual_card_remote_data_source.dart';
import '../../data/repositories/virtual_card_repository_impl.dart';
import '../../domain/entities/virtual_card.dart';
import '../../domain/repositories/virtual_card_repository.dart';
import '../utils/credential_club_type.dart';

final _virtualCardDioProvider = Provider<Dio>(
  (ref) => DioClient.createDio(
    actingForSession: ref.read(actingForSessionProvider),
  ),
);

final virtualCardRemoteDataSourceProvider =
    Provider<VirtualCardRemoteDataSource>((ref) {
  final dio = ref.watch(_virtualCardDioProvider);
  return VirtualCardRemoteDataSourceImpl(
    dio: dio,
    baseUrl: AppConstants.baseUrl,
  );
});

final virtualCardRepositoryProvider = Provider<VirtualCardRepository>((ref) {
  final remoteDataSource = ref.read(virtualCardRemoteDataSourceProvider);
  final networkInfo = ref.read(networkInfoProvider);

  return VirtualCardRepositoryImpl(
    remoteDataSource: remoteDataSource,
    networkInfo: networkInfo,
  );
});

final virtualCardFetcherProvider =
    FutureProvider.autoDispose<VirtualCard>((ref) async {
  ref.keepAlive();

  // Mientras se actúa por un dependiente la credencial NO toca el disco: ni se
  // lee un caché ni se escribe uno (FP-49, FP-51). Se decide al EMPEZAR: si el
  // tutor sale mientras la petición vuela, la tarjeta del dependiente igual no
  // se guarda.
  final session = ref.read(actingForSessionProvider);
  final actingAtStart = session.isActing;

  final user = await ref.watch(authNotifierProvider.selectAsync((u) => u));
  if (user == null) {
    throw Exception('virtual_card.errors.not_authenticated'.tr());
  }

  final repository = ref.read(virtualCardRepositoryProvider);
  final cached = actingAtStart ? null : await repository.getCachedCard(user.id);
  final connected = await ref.read(networkInfoProvider).isConnected;

  if (connected) {
    try {
      final remote = await repository.getRemoteCard();
      if (!actingAtStart) {
        await repository.saveCachedCard(remote);
      }
      return _withIdentity(remote.copyWith(isOffline: false), user);
    } on ConnectionException {
      if (cached != null) {
        return _withIdentity(cached.copyWith(isOffline: true), user);
      }
      return _buildFallbackCard(ref, user, isOffline: true);
    } on ServerException catch (error) {
      if (!isVirtualCardRateLimit(error)) rethrow;

      _notifyVirtualCardRateLimit(ref);
      if (cached != null) {
        return _withIdentity(cached.copyWith(isOffline: true), user);
      }
      return _buildFallbackCard(ref, user, isOffline: true);
    }
  }

  if (cached != null) {
    return _withIdentity(cached.copyWith(isOffline: true), user);
  }

  return _buildFallbackCard(ref, user, isOffline: true);
});

final virtualCardProvider = Provider<AsyncValue<VirtualCard>>(
  (ref) => ref.watch(virtualCardFetcherProvider),
);

final virtualCardRateLimitNoticeProvider = StateProvider<int>((ref) => 0);

Future<VirtualCard> _buildFallbackCard(
  Ref ref,
  UserEntity user, {
  required bool isOffline,
}) async {
  final profileValue = ref.read(profileNotifierProvider);
  UserDetail? profile = profileValue.valueOrNull;
  if (profile == null) {
    try {
      profile = await ref.read(profileNotifierProvider.future);
    } catch (_) {
      profile = null;
    }
  }

  QrMemberToken? qrToken;
  try {
    qrToken = await ref.read(qrMemberTokenProvider.future);
  } catch (_) {
    qrToken = null;
  }

  final activeGrant = user.authorization?.activeGrant;
  final identityClubType = resolveCredentialClubType(
    user.authorization?.clubAssignments ?? const [],
  );
  final displayName =
      _pickNonEmpty([profile?.fullName, user.name, user.email]) ?? '';

  final roleLabel = _pickNonEmpty([activeGrant?.roleName]);
  final roleCode = _pickNonEmpty([activeGrant?.roleName]);
  final clubName = _pickNonEmpty([
    profile?.clubName,
    activeGrant?.clubTypeName,
  ]);
  final sectionName = _pickNonEmpty([
    identityClubType,
    profile?.clubType,
    activeGrant?.clubTypeName,
  ]);
  final photoUrl = _pickNonEmpty([
    profile?.avatar,
    user.avatar,
  ]);
  final currentClass = _pickNonEmpty([profile?.currentClass]);
  final bloodType = _pickNonEmpty([profile?.blood]);

  return VirtualCard(
    userId: user.id,
    fullName: displayName,
    photoUrl: photoUrl,
    roleLabel: roleLabel,
    roleCode: roleCode,
    clubName: clubName,
    clubLogoUrl: null,
    sectionName: sectionName,
    memberSince: profile?.createdAt ?? user.createdAt,
    achievementTier: null,
    cardIdShort: null,
    qrToken: qrToken?.token,
    qrExpiresAt: qrToken?.expiresAt ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    isActive: user.authorization?.activeGrant?.isActive ?? true,
    isOffline: isOffline,
    currentClass: currentClass,
    bloodType: bloodType,
  );
}

String? _pickNonEmpty(Iterable<String?> values) {
  for (final value in values) {
    final normalized = value?.trim();
    if (normalized != null && normalized.isNotEmpty) {
      return normalized;
    }
  }
  return null;
}

VirtualCard _withIdentity(VirtualCard card, UserEntity user) {
  return applyCredentialIdentity(
    card: card,
    assignments: user.authorization?.clubAssignments ?? const [],
  );
}

bool isVirtualCardRateLimit(Object error) {
  return error is ServerException && error.code == 429;
}

void _notifyVirtualCardRateLimit(Ref ref) {
  final notifier = ref.read(virtualCardRateLimitNoticeProvider.notifier);
  notifier.state = notifier.state + 1;
}
