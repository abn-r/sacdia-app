import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sacdia_app/core/constants/app_constants.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/providers/storage_provider.dart';

/// Acento de sistema elegido en Configuración. Por defecto, azul del icono.
class AccentNotifier extends Notifier<SacAccent> {
  @override
  SacAccent build() {
    final saved =
        ref.read(sharedPreferencesProvider).getString(AppConstants.accentKey);
    return SacAccent.byId(saved);
  }

  Future<void> setAccent(SacAccent accent) async {
    state = accent;
    await ref
        .read(sharedPreferencesProvider)
        .setString(AppConstants.accentKey, accent.id);
  }
}

final accentNotifierProvider = NotifierProvider<AccentNotifier, SacAccent>(
  AccentNotifier.new,
);
