import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Interfaz para el almacenamiento seguro de datos sensibles
abstract class SecureStorage {
  Future<void> write(String key, String value);
  Future<String?> read(String key);
  Future<bool> contains(String key);
  Future<void> delete(String key);
  Future<void> deleteAll();
  Future<Map<String, String>> readAll();
}

/// Implementación de SecureStorage con FlutterSecureStorage
class SecureStorageImpl implements SecureStorage {
  final FlutterSecureStorage _storage;
  
  SecureStorageImpl({FlutterSecureStorage? storage}) : 
    _storage = storage ?? const FlutterSecureStorage(
      aOptions: AndroidOptions(
        encryptedSharedPreferences: true,
      ),
    );
  
  @override
  Future<void> write(String key, String value) async {
    await _storage.write(key: key, value: value);
  }
  
  @override
  Future<String?> read(String key) async {
    return await _storage.read(key: key);
  }
  
  @override
  Future<bool> contains(String key) async {
    return await _storage.containsKey(key: key);
  }
  
  @override
  Future<void> delete(String key) async {
    await _storage.delete(key: key);
  }
  
  @override
  Future<void> deleteAll() async {
    await _storage.deleteAll();
  }
  
  @override
  Future<Map<String, String>> readAll() async {
    return await _storage.readAll();
  }
}
