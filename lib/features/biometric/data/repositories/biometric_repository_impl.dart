import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/app_logger.dart';
import '../../domain/entities/biometric_capability.dart';
import '../../domain/entities/biometric_settings.dart';
import '../../domain/repositories/biometric_repository.dart';

/// Implementación concreta de [BiometricRepository].
///
/// - Usa `local_auth` para invocar el prompt biométrico nativo.
/// - Persiste el opt-in en [SharedPreferences] (NO en SecureStorage porque
///   no es PII sensible y solo es un flag booleano + timestamp).
/// - Siempre fuerza revalidación (no hay cache de sesión biométrica).
class BiometricRepositoryImpl implements BiometricRepository {
  static const String _tag = 'BiometricRepository';

  final LocalAuthentication _localAuth;
  final SharedPreferences _prefs;

  BiometricRepositoryImpl({
    required SharedPreferences prefs,
    LocalAuthentication? localAuth,
  })  : _prefs = prefs,
        _localAuth = localAuth ?? LocalAuthentication();

  @override
  Future<BiometricCapability> getCapability() async {
    try {
      final isSupported = await _localAuth.isDeviceSupported();
      if (!isSupported) {
        return const BiometricCapability.unsupported();
      }
      final canCheck = await _localAuth.canCheckBiometrics;
      final types = canCheck
          ? await _localAuth.getAvailableBiometrics()
          : <BiometricType>[];
      return BiometricCapability(
        deviceSupportsBiometric: isSupported,
        hasEnrolledBiometrics: canCheck && types.isNotEmpty,
        availableTypes: types,
      );
    } on PlatformException catch (e) {
      AppLogger.w(
        'getCapability falló',
        tag: _tag,
        error: e,
      );
      return const BiometricCapability.unsupported();
    }
  }

  @override
  Future<BiometricSettings> readSettings() async {
    final enabled = _prefs.getBool(AppConstants.biometricEnabledKey) ?? false;
    final raw = _prefs.getString(AppConstants.biometricEnrolledAtKey);
    DateTime? enrolledAt;
    if (raw != null && raw.isNotEmpty) {
      enrolledAt = DateTime.tryParse(raw);
    }
    return BiometricSettings(enabled: enabled, enrolledAt: enrolledAt);
  }

  @override
  Future<void> saveSettings(BiometricSettings settings) async {
    await _prefs.setBool(
      AppConstants.biometricEnabledKey,
      settings.enabled,
    );
    if (settings.enrolledAt != null) {
      await _prefs.setString(
        AppConstants.biometricEnrolledAtKey,
        settings.enrolledAt!.toIso8601String(),
      );
    } else {
      await _prefs.remove(AppConstants.biometricEnrolledAtKey);
    }
  }

  @override
  Future<void> clearSettings() async {
    await _prefs.remove(AppConstants.biometricEnabledKey);
    await _prefs.remove(AppConstants.biometricEnrolledAtKey);
  }

  @override
  Future<bool> authenticate({required String reason}) async {
    try {
      final ok = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false, // permite PIN/passcode como fallback del SO
          stickyAuth: true,
          sensitiveTransaction: true,
          useErrorDialogs: true,
        ),
        authMessages: const <AuthMessages>[
          AndroidAuthMessages(
            signInTitle: 'SACDIA',
            cancelButton: 'Cancelar',
          ),
          IOSAuthMessages(
            cancelButton: 'Cancelar',
          ),
        ],
      );
      return ok;
    } on PlatformException catch (e) {
      AppLogger.w(
        'authenticate falló: ${e.code}',
        tag: _tag,
        error: e,
      );
      return false;
    }
  }

  @override
  Future<void> stopAuthentication() async {
    try {
      await _localAuth.stopAuthentication();
    } on PlatformException {
      // no-op
    }
  }
}
