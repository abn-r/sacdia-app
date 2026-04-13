import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Interfaz para el almacenamiento local de datos
abstract class LocalStorage {
  Future<bool> saveString(String key, String value);
  Future<bool> saveBool(String key, bool value);
  Future<bool> saveInt(String key, int value);
  Future<bool> saveDouble(String key, double value);
  Future<bool> saveStringList(String key, List<String> value);
  Future<bool> saveMap(String key, Map<String, dynamic> value);
  Future<bool> saveObject<T>(String key, T value, T Function(Map<String, dynamic> json) fromJson);
  
  String? getString(String key);
  bool? getBool(String key);
  int? getInt(String key);
  double? getDouble(String key);
  List<String>? getStringList(String key);
  Map<String, dynamic>? getMap(String key);
  T? getObject<T>(String key, T Function(Map<String, dynamic> json) fromJson);
  
  Future<bool> remove(String key);
  Future<bool> clear();
  bool containsKey(String key);
  Set<String> getKeys();

  // ── TTL helpers ────────────────────────────────────────────────────────────

  /// Records the current timestamp for [key] so callers can later check
  /// whether the cached data has expired via [isExpired].
  ///
  /// Call this alongside [saveMap] / [saveString] when writing data that
  /// should have a time-to-live. Example:
  /// ```dart
  /// await storage.saveMap('user', userJson);
  /// await storage.setCachedAt('user');
  /// ```
  Future<bool> setCachedAt(String key);

  /// Returns the epoch-millisecond timestamp recorded by [setCachedAt], or
  /// null if no timestamp was stored for [key].
  int? getCachedAt(String key);

  /// Returns true if the cached timestamp for [key] is older than [maxAge]
  /// (default 24 hours), or if no timestamp exists for [key].
  ///
  /// Callers should treat a missing timestamp as expired so they always
  /// re-fetch when the TTL capability was not previously set.
  bool isExpired(String key, {Duration maxAge = const Duration(hours: 24)});
}

/// Implementación de LocalStorage con SharedPreferences
class SharedPreferencesStorage implements LocalStorage {
  final SharedPreferences _prefs;
  
  SharedPreferencesStorage(this._prefs);
  
  @override
  Future<bool> saveString(String key, String value) async {
    return await _prefs.setString(key, value);
  }
  
  @override
  Future<bool> saveBool(String key, bool value) async {
    return await _prefs.setBool(key, value);
  }
  
  @override
  Future<bool> saveInt(String key, int value) async {
    return await _prefs.setInt(key, value);
  }
  
  @override
  Future<bool> saveDouble(String key, double value) async {
    return await _prefs.setDouble(key, value);
  }
  
  @override
  Future<bool> saveStringList(String key, List<String> value) async {
    return await _prefs.setStringList(key, value);
  }
  
  @override
  Future<bool> saveMap(String key, Map<String, dynamic> value) async {
    return await _prefs.setString(key, jsonEncode(value));
  }
  
  @override
  Future<bool> saveObject<T>(
    String key, 
    T value, 
    T Function(Map<String, dynamic> json) fromJson
  ) async {
    if (value == null) {
      return false;
    }
    
    if (value is Map<String, dynamic>) {
      return await saveMap(key, value);
    } else {
      // Asumimos que el objeto tiene un método toJson()
      try {
        final jsonData = (value as dynamic).toJson();
        return await saveMap(key, jsonData);
      } catch (e) {
        return false;
      }
    }
  }
  
  @override
  String? getString(String key) {
    return _prefs.getString(key);
  }
  
  @override
  bool? getBool(String key) {
    return _prefs.getBool(key);
  }
  
  @override
  int? getInt(String key) {
    return _prefs.getInt(key);
  }
  
  @override
  double? getDouble(String key) {
    return _prefs.getDouble(key);
  }
  
  @override
  List<String>? getStringList(String key) {
    return _prefs.getStringList(key);
  }
  
  @override
  Map<String, dynamic>? getMap(String key) {
    final data = _prefs.getString(key);
    if (data == null) {
      return null;
    }
    
    try {
      return jsonDecode(data) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }
  
  @override
  T? getObject<T>(String key, T Function(Map<String, dynamic> json) fromJson) {
    final map = getMap(key);
    if (map == null) {
      return null;
    }
    
    try {
      return fromJson(map);
    } catch (e) {
      return null;
    }
  }
  
  @override
  Future<bool> remove(String key) async {
    return await _prefs.remove(key);
  }

  @override
  Future<bool> clear() async {
    return await _prefs.clear();
  }

  @override
  bool containsKey(String key) {
    return _prefs.containsKey(key);
  }

  @override
  Set<String> getKeys() {
    return _prefs.getKeys();
  }

  // ── TTL helpers ────────────────────────────────────────────────────────────

  /// Suffix appended to the original key to store the cached-at timestamp.
  static const String _cachedAtSuffix = '_cached_at';

  @override
  Future<bool> setCachedAt(String key) async {
    return await _prefs.setInt(
      '$key$_cachedAtSuffix',
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  @override
  int? getCachedAt(String key) {
    return _prefs.getInt('$key$_cachedAtSuffix');
  }

  @override
  bool isExpired(String key, {Duration maxAge = const Duration(hours: 24)}) {
    final cachedAt = getCachedAt(key);
    if (cachedAt == null) return true;
    final age = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(cachedAt));
    return age > maxAge;
  }
}
