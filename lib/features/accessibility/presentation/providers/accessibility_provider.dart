import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/storage_provider.dart';
import '../../data/repositories/accessibility_repository_impl.dart';
import '../../domain/entities/accessibility_settings.dart';
import '../../domain/repositories/accessibility_repository.dart';

/// Provider del repositorio (inyecta SharedPreferences desde storage_provider).
final accessibilityRepositoryProvider = Provider<AccessibilityRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return AccessibilityRepositoryImpl(prefs);
});

/// Notifier de preferencias de accesibilidad.
///
/// Sigue el mismo patrón que [ThemeNotifier]: el estado ES la entidad
/// [AccessibilitySettings]; cada setter aplica optimistic update en memoria
/// y luego persiste (fire-and-forget await). No hay estados intermedios de
/// loading porque la lectura es síncrona desde la instancia ya cargada en
/// `main()`.
class AccessibilityNotifier extends Notifier<AccessibilitySettings> {
  @override
  AccessibilitySettings build() {
    return ref.read(accessibilityRepositoryProvider).load();
  }

  Future<void> setTextSize(TextSizeOption option) async {
    state = state.copyWith(textSize: option);
    await ref.read(accessibilityRepositoryProvider).save(state);
  }

  Future<void> setHighContrast(bool value) async {
    state = state.copyWith(highContrast: value);
    await ref.read(accessibilityRepositoryProvider).save(state);
  }

  Future<void> setReduceMotion(bool value) async {
    state = state.copyWith(reduceMotion: value);
    await ref.read(accessibilityRepositoryProvider).save(state);
  }
}

final accessibilityProvider =
    NotifierProvider<AccessibilityNotifier, AccessibilitySettings>(() {
  return AccessibilityNotifier();
});

/// Helper que fusiona las preferencias de accesibilidad con el [MediaQueryData]
/// actual. Se usa como base tanto en el override raíz de [main.dart] (para
/// propagar a toda la app) como en el preview de la vista de accesibilidad.
///
/// Reglas:
/// - Si `textScaleFactor` es null → se respeta el [TextScaler] actual.
/// - [MediaQueryData.disableAnimations] se propaga OR con el flag del usuario
///   (no se sobrescribe el del sistema si ya estaba activo).
MediaQueryData mergedAccessibilityMediaQueryData(
  MediaQueryData base,
  AccessibilitySettings settings,
) {
  final factor = settings.textScaleFactor;
  return base.copyWith(
    textScaler: factor != null ? TextScaler.linear(factor) : base.textScaler,
    disableAnimations: settings.reduceMotion || base.disableAnimations,
  );
}
