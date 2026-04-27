import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

final _virtualCardDioProvider = Provider<Dio>((ref) => DioClient.createDio());

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

  final user = await ref.watch(authNotifierProvider.selectAsync((u) => u));
  if (user == null) {
    throw Exception('virtual_card.errors.not_authenticated'.tr());
  }

  final repository = ref.read(virtualCardRepositoryProvider);
  final cached = await repository.getCachedCard(user.id);
  final connected = await ref.read(networkInfoProvider).isConnected;

  if (connected) {
    try {
      final remote = await repository.getRemoteCard();
      await repository.saveCachedCard(remote);
      return remote.copyWith(isOffline: false);
    } on ConnectionException {
      if (cached != null) {
        return cached.copyWith(isOffline: true);
      }
      return _buildFallbackCard(ref, user, isOffline: true);
    }
  }

  if (cached != null) {
    return cached.copyWith(isOffline: true);
  }

  return _buildFallbackCard(ref, user, isOffline: true);
});

final virtualCardProvider = Provider<AsyncValue<VirtualCard>>(
  (ref) => ref.watch(virtualCardFetcherProvider),
);

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
  final displayName =
      _pickNonEmpty([profile?.fullName, user.name, user.email]) ?? user.email;

  final roleLabel = _pickNonEmpty([activeGrant?.roleName]);
  final roleCode = _pickNonEmpty([activeGrant?.roleName]);
  final clubName = _pickNonEmpty([
    profile?.clubName,
    activeGrant?.clubTypeName,
  ]);
  final sectionName = _pickNonEmpty([profile?.currentClass]);
  final photoUrl = _pickNonEmpty([
    profile?.avatar,
    user.avatar,
  ]);

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
    qrExpiresAt: qrToken?.expiresAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    isActive: user.authorization?.activeGrant?.isActive ?? true,
    isOffline: isOffline,
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
