import 'package:dartz/dartz.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/utils/app_logger.dart';
import '../../domain/entities/notification_preferences.dart';
import '../../domain/repositories/notification_preferences_repository.dart';
import '../datasources/notification_preferences_remote_data_source.dart';
import '../models/notification_preferences_model.dart';

/// Implementación offline-first del repositorio de preferencias.
///
/// - GET: intenta red primero; si falla devuelve caché local (SharedPreferences).
/// - PATCH: persiste optimistamente en local y luego llama al backend.
class NotificationPreferencesRepositoryImpl
    implements NotificationPreferencesRepository {
  final NotificationPreferencesRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  static const _tag = 'NotifPrefsRepo';

  // Keys de SharedPreferences (mismas que usa settings_view internamente
  // para que la migración sea transparente).
  static const _kMaster = 'notif_push_master';
  static const _kActivities = 'notif_push_activities';
  static const _kAchievements = 'notif_push_achievements';
  static const _kApprovals = 'notif_push_approvals';
  static const _kInvitations = 'notif_push_invitations';
  static const _kReminders = 'notif_push_reminders';

  NotificationPreferencesRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, NotificationPreferences>> getPreferences() async {
    final hasConnection = await networkInfo.isConnected;

    if (!hasConnection) {
      AppLogger.w('Sin red — devolviendo preferencias desde caché', tag: _tag);
      final cached = await _readFromCache();
      return Right(cached);
    }

    try {
      final model = await remoteDataSource.getPreferences();
      // Reconciliar: persiste en caché para acceso offline
      await _writeToCache(model);
      return Right(model);
    } on ServerException catch (e) {
      AppLogger.w(
        'Error del servidor al obtener preferencias — usando caché',
        tag: _tag,
        error: e,
      );
      final cached = await _readFromCache();
      return Right(cached);
    } catch (e) {
      AppLogger.e('Error inesperado al obtener preferencias', tag: _tag, error: e);
      return Left(ServerFailure(
          message: tr('profile.notification_preferences.errors.fetch_failed',
              namedArgs: {'detail': '$e'})));
    }
  }

  @override
  Future<Either<Failure, NotificationPreferences>> updatePreferences(
    Map<String, bool> delta,
  ) async {
    try {
      final model = await remoteDataSource.updatePreferences(delta);
      // Persiste el estado completo retornado por el server (incluye cascada
      // si master=false pone subcategorías en false).
      await _writeToCache(model);
      return Right(model);
    } on ServerException catch (e) {
      AppLogger.w(
        'Error del servidor al actualizar preferencias',
        tag: _tag,
        error: e,
      );
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      AppLogger.e('Error inesperado al actualizar preferencias', tag: _tag, error: e);
      return Left(ServerFailure(
          message: tr('profile.notification_preferences.errors.update_failed',
              namedArgs: {'detail': '$e'})));
    }
  }

  // ── Cache helpers ──────────────────────────────────────────────────────────

  Future<NotificationPreferencesModel> _readFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    return NotificationPreferencesModel.fromPrefsMap({
      _kMaster: prefs.getBool(_kMaster),
      _kActivities: prefs.getBool(_kActivities),
      _kAchievements: prefs.getBool(_kAchievements),
      _kApprovals: prefs.getBool(_kApprovals),
      _kInvitations: prefs.getBool(_kInvitations),
      _kReminders: prefs.getBool(_kReminders),
    });
  }

  Future<void> _writeToCache(NotificationPreferencesModel model) async {
    final prefs = await SharedPreferences.getInstance();
    final map = model.toPrefsMap();
    for (final entry in map.entries) {
      await prefs.setBool(entry.key, entry.value);
    }
  }
}
