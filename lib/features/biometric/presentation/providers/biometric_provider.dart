import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/storage_provider.dart';
import '../../data/repositories/biometric_repository_impl.dart';
import '../../domain/entities/biometric_capability.dart';
import '../../domain/entities/biometric_settings.dart';
import '../../domain/repositories/biometric_repository.dart';

/// Provider del repositorio biométrico.
///
/// Depende de [sharedPreferencesProvider] (ya overridden en `main.dart`).
final biometricRepositoryProvider = Provider<BiometricRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return BiometricRepositoryImpl(prefs: prefs);
});

/// Capability del dispositivo (hardware + enrolamiento).
///
/// Es un [FutureProvider] porque la evaluación toca MethodChannels nativos.
/// Idempotente: se puede refrescar con `ref.invalidate(biometricCapabilityProvider)`.
final biometricCapabilityProvider =
    FutureProvider<BiometricCapability>((ref) async {
  final repo = ref.watch(biometricRepositoryProvider);
  return repo.getCapability();
});

/// Estado UI + persistencia del opt-in biométrico.
///
/// Expone además [unlocked], una bandera EFÍMERA en memoria que:
/// - nace en `false` en cada cold start (por diseño, revalidamos siempre),
/// - se eleva a `true` cuando el usuario pasa el gate de [AppLockView],
/// - no se persiste nunca.
class BiometricState {
  final BiometricSettings settings;
  final bool unlocked;

  const BiometricState({
    required this.settings,
    required this.unlocked,
  });

  const BiometricState.initial()
      : settings = const BiometricSettings.disabled(),
        unlocked = false;

  bool get enabled => settings.enabled;

  BiometricState copyWith({
    BiometricSettings? settings,
    bool? unlocked,
  }) {
    return BiometricState(
      settings: settings ?? this.settings,
      unlocked: unlocked ?? this.unlocked,
    );
  }
}

class BiometricNotifier extends Notifier<BiometricState> {
  @override
  BiometricState build() {
    // Carga sincronizada del flag persistido. No leemos capability aquí
    // para no bloquear el primer frame — la UI lo hace vía FutureProvider.
    _hydrate();
    return const BiometricState.initial();
  }

  Future<void> _hydrate() async {
    final repo = ref.read(biometricRepositoryProvider);
    final s = await repo.readSettings();
    state = state.copyWith(settings: s);
  }

  BiometricRepository get _repo => ref.read(biometricRepositoryProvider);

  /// Marca la sesión como desbloqueada (post-biometric-gate).
  /// Efímero — se resetea en cold start.
  void markUnlocked() {
    if (!state.unlocked) {
      state = state.copyWith(unlocked: true);
    }
  }

  /// Re-lockea la sesión en memoria (útil si se invoca desde un action manual).
  void lock() {
    if (state.unlocked) {
      state = state.copyWith(unlocked: false);
    }
  }

  /// Habilita biometría tras confirmar con el prompt nativo.
  ///
  /// Devuelve un [BiometricEnableResult] para que la UI muestre mensajes
  /// contextuales según el motivo de fallo (no soportado, no enrolado,
  /// cancelado).
  Future<BiometricEnableResult> enable({required String reason}) async {
    final capability = await _repo.getCapability();
    if (!capability.deviceSupportsBiometric) {
      return BiometricEnableResult.notSupported;
    }
    if (!capability.hasEnrolledBiometrics) {
      return BiometricEnableResult.noneEnrolled;
    }
    final ok = await _repo.authenticate(reason: reason);
    if (!ok) {
      return BiometricEnableResult.authFailed;
    }
    final newSettings = BiometricSettings(
      enabled: true,
      enrolledAt: DateTime.now(),
    );
    await _repo.saveSettings(newSettings);
    state = state.copyWith(settings: newSettings, unlocked: true);
    return BiometricEnableResult.ok;
  }

  /// Desactiva biometría. No requiere reautenticación — el usuario ya pasó
  /// el gate para llegar a settings. Si se quiere endurecer, puede
  /// envolverse con [requireBiometricConfirmation].
  Future<void> disable() async {
    await _repo.clearSettings();
    state = const BiometricState.initial();
  }

  /// Autenticación one-shot para app-lock o acciones sensibles.
  Future<bool> authenticate({required String reason}) async {
    final ok = await _repo.authenticate(reason: reason);
    if (ok) markUnlocked();
    return ok;
  }
}

enum BiometricEnableResult {
  ok,
  notSupported,
  noneEnrolled,
  authFailed,
}

final biometricProvider =
    NotifierProvider<BiometricNotifier, BiometricState>(BiometricNotifier.new);

/// Helper para proteger acciones sensibles (borrar cuenta, exportar datos,
/// cerrar sesiones remotas, cambiar contraseña).
///
/// - Si biometría está OFF → devuelve `true` (no-op). Las acciones sensibles
///   SIEMPRE deben tener además su propia confirmación (AlertDialog).
/// - Si está ON → dispara el prompt nativo y devuelve el resultado.
Future<bool> requireBiometricConfirmation(
  BuildContext context,
  WidgetRef ref, {
  required String reason,
}) async {
  final enabled = ref.read(biometricProvider).enabled;
  if (!enabled) return true;
  final notifier = ref.read(biometricProvider.notifier);
  return notifier.authenticate(reason: reason);
}

/// Variante para consumidores sin [WidgetRef] directo.
Future<bool> requireBiometricConfirmationRef(
  Ref ref, {
  required String reason,
}) async {
  final enabled = ref.read(biometricProvider).enabled;
  if (!enabled) return true;
  final notifier = ref.read(biometricProvider.notifier);
  return notifier.authenticate(reason: reason);
}

/// i18n-friendly default messages. Los consumidores pueden sobreescribir.
class BiometricReasons {
  BiometricReasons._();

  static String unlock() => 'biometric.unlock_reason'.tr();
  static String enroll() => 'biometric.enroll_reason'.tr();
  static String confirmSensitive() => 'biometric.confirm_sensitive_action'.tr();
}
