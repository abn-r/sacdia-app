import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/utils/app_logger.dart';
import '../../domain/entities/virtual_card.dart';
import '../../domain/repositories/virtual_card_repository.dart';
import '../datasources/virtual_card_remote_data_source.dart';
import '../models/virtual_card_model.dart';

class VirtualCardRepositoryImpl implements VirtualCardRepository {
  VirtualCardRepositoryImpl({
    required VirtualCardRemoteDataSource remoteDataSource,
    required NetworkInfo networkInfo,
  })  : _remoteDataSource = remoteDataSource,
        _networkInfo = networkInfo;

  final VirtualCardRemoteDataSource _remoteDataSource;
  final NetworkInfo _networkInfo;

  static const _tag = 'VirtualCardRepo';

  @override
  Future<VirtualCard> getRemoteCard() async {
    final hasConnection = await _networkInfo.isConnected;
    if (!hasConnection) {
      throw ServerException(message: tr('virtual_card.errors.offline'));
    }

    try {
      return await _remoteDataSource.getVirtualCard();
    } on ServerException catch (e) {
      AppLogger.w('Tarjeta virtual remota no disponible', tag: _tag, error: e);
      rethrow;
    } on AppException {
      rethrow;
    } catch (e) {
      AppLogger.e('Error inesperado al obtener tarjeta virtual', tag: _tag, error: e);
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<VirtualCard?> getCachedCard(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey(userId));
    if (raw == null || raw.isEmpty) return null;

    try {
      final map = jsonDecode(raw);
      if (map is Map) {
        return VirtualCardModel.fromJson(Map<String, dynamic>.from(map));
      }
      return null;
    } catch (e) {
      AppLogger.w('Caché de tarjeta virtual corrupta', tag: _tag, error: e);
      return null;
    }
  }

  @override
  Future<void> saveCachedCard(VirtualCard card) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cacheKey(card.userId),
      jsonEncode(
        VirtualCardModel(
          userId: card.userId,
          fullName: card.fullName,
          photoUrl: card.photoUrl,
          roleLabel: card.roleLabel,
          roleCode: card.roleCode,
          clubName: card.clubName,
          clubLogoUrl: card.clubLogoUrl,
          sectionName: card.sectionName,
          memberSince: card.memberSince,
          achievementTier: card.achievementTier,
          cardIdShort: card.cardIdShort,
          qrToken: card.qrToken,
          qrExpiresAt: card.qrExpiresAt,
          isActive: card.isActive,
          isOffline: card.isOffline,
        ).toJson(),
      ),
    );
  }

  String _cacheKey(String userId) => 'virtual_card_cache_$userId';
}
