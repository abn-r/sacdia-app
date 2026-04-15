import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../models/achievement_category_model.dart';
import '../models/achievement_model.dart';
import '../models/user_achievement_model.dart';

/// Estructura de respuesta de GET /achievements/me
class UserAchievementsResponseRaw {
  final Map<String, dynamic> summary;
  final List<UserAchievementCategoryGroupRaw> categories;

  const UserAchievementsResponseRaw({
    required this.summary,
    required this.categories,
  });
}

/// Categoría con logros y progreso crudo
class UserAchievementCategoryGroupRaw {
  final AchievementCategoryModel category;
  final List<AchievementWithProgressRaw> achievements;

  const UserAchievementCategoryGroupRaw({
    required this.category,
    required this.achievements,
  });
}

/// Logro con su progreso crudo (userAchievement puede ser null)
class AchievementWithProgressRaw {
  final AchievementModel achievement;
  final UserAchievementModel? userAchievement;

  const AchievementWithProgressRaw({
    required this.achievement,
    this.userAchievement,
  });
}

/// Interfaz para la fuente de datos remota de logros
abstract class AchievementsRemoteDataSource {
  /// GET /achievements — catálogo agrupado por categoría
  Future<List<UserAchievementCategoryGroupRaw>> getAchievements({
    CancelToken? cancelToken,
  });

  /// GET /achievements/me — logros del usuario con summary
  Future<UserAchievementsResponseRaw> getUserAchievements({
    CancelToken? cancelToken,
  });

  /// GET /achievements/categories — lista de categorías
  Future<List<AchievementCategoryModel>> getCategories({
    CancelToken? cancelToken,
  });
}

/// Implementación de la fuente de datos remota de logros
class AchievementsRemoteDataSourceImpl implements AchievementsRemoteDataSource {
  final Dio _dio;
  final String _baseUrl;

  static const _tag = 'AchievementsDS';

  AchievementsRemoteDataSourceImpl({
    required Dio dio,
    required String baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl;

  @override
  Future<List<UserAchievementCategoryGroupRaw>> getAchievements({
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.achievements}',
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // GET /achievements returns { categories: [...], meta: {...} }
        final body = response.data;
        final List<dynamic> data;
        if (body is Map<String, dynamic> && body['categories'] is List) {
          data = body['categories'] as List<dynamic>;
        } else if (body is List) {
          // Fallback: legacy flat list shape
          data = body;
        } else {
          data = const [];
        }
        return data
            .map((json) => _parseCatalogGroupRaw(json as Map<String, dynamic>))
            .toList();
      }

      throw ServerException(
        message: 'Error al obtener catálogo de logros',
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en getAchievements', tag: _tag, error: e);
      if (e is DioException) {
        if (e.type == DioExceptionType.cancel) rethrow;
        throw ServerException(
          message: e.message ?? 'Error de conexión',
          code: e.response?.statusCode,
        );
      }
      if (e is ServerException || e is AuthException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<UserAchievementsResponseRaw> getUserAchievements({
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.achievements}/me',
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final raw = response.data as Map<String, dynamic>;
        final summary = raw['summary'] as Map<String, dynamic>? ?? {};
        final categoriesRaw = raw['categories'] as List<dynamic>? ?? [];

        final categories = categoriesRaw
            .map((json) => _parseUserGroupRaw(json as Map<String, dynamic>))
            .toList();

        return UserAchievementsResponseRaw(
          summary: summary,
          categories: categories,
        );
      }

      throw ServerException(
        message: 'Error al obtener logros del usuario',
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en getUserAchievements', tag: _tag, error: e);
      if (e is DioException) {
        if (e.type == DioExceptionType.cancel) rethrow;
        throw ServerException(
          message: e.message ?? 'Error de conexión',
          code: e.response?.statusCode,
        );
      }
      if (e is ServerException || e is AuthException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<List<AchievementCategoryModel>> getCategories({
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.achievements}/categories',
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final List<dynamic> data = response.data as List<dynamic>;
        return data
            .map((json) =>
                AchievementCategoryModel.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      throw ServerException(
        message: 'Error al obtener categorías de logros',
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en getCategories', tag: _tag, error: e);
      if (e is DioException) {
        if (e.type == DioExceptionType.cancel) rethrow;
        throw ServerException(
          message: e.message ?? 'Error de conexión',
          code: e.response?.statusCode,
        );
      }
      if (e is ServerException || e is AuthException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  // ── Private helpers ──────────────────────────────────────────────────────────

  /// Parses a category group from GET /achievements/me.
  ///
  /// Backend shape:
  /// ```json
  /// {
  ///   "category_id": 1,
  ///   "name": "General",
  ///   "icon": null,
  ///   "display_order": 0,
  ///   "achievements": [
  ///     { "achievement": { ...fields }, "user_achievement": { ...fields } | null }
  ///   ]
  /// }
  /// ```
  UserAchievementCategoryGroupRaw _parseUserGroupRaw(
      Map<String, dynamic> json) {
    final category = AchievementCategoryModel.fromJson(json);

    final achievementsRaw = json['achievements'] as List<dynamic>? ?? [];
    final achievements = achievementsRaw.map((item) {
      final itemMap = item as Map<String, dynamic>;

      final achievementJson =
          itemMap['achievement'] as Map<String, dynamic>? ?? itemMap;
      final userAchievementJson =
          itemMap['user_achievement'] as Map<String, dynamic>?;

      return AchievementWithProgressRaw(
        achievement: AchievementModel.fromJson(achievementJson),
        userAchievement: userAchievementJson != null
            ? UserAchievementModel.fromJson(userAchievementJson)
            : null,
      );
    }).toList();

    return UserAchievementCategoryGroupRaw(
      category: category,
      achievements: achievements,
    );
  }

  /// Parses a category group from GET /achievements (catalog endpoint).
  ///
  /// Backend shape uses `category_name` for the name and flat achievement
  /// objects (no user_achievement wrapper — user hasn't interacted with them).
  ///
  /// ```json
  /// {
  ///   "category_id": 1,
  ///   "category_name": "General",
  ///   "icon": null,
  ///   "display_order": 0,
  ///   "achievements": [ { ...flat achievement fields } ]
  /// }
  /// ```
  UserAchievementCategoryGroupRaw _parseCatalogGroupRaw(
      Map<String, dynamic> json) {
    // Normalise the category JSON: catalog uses `category_name`, model reads `name`
    final normalised = <String, dynamic>{
      ...json,
      if (json['name'] == null && json['category_name'] != null)
        'name': json['category_name'],
    };
    final category = AchievementCategoryModel.fromJson(normalised);

    final achievementsRaw = json['achievements'] as List<dynamic>? ?? [];
    final achievements = achievementsRaw.map((item) {
      final itemMap = item as Map<String, dynamic>;
      return AchievementWithProgressRaw(
        achievement: AchievementModel.fromJson(itemMap),
        userAchievement: null, // catalog endpoint never returns user progress
      );
    }).toList();

    return UserAchievementCategoryGroupRaw(
      category: category,
      achievements: achievements,
    );
  }
}
