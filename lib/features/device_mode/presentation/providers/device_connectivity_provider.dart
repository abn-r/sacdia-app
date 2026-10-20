import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';

/// ¿Hay red ahora? Primero la lectura puntual y luego los cambios.
///
/// El teléfono vinculado ve lo último guardado sin red (solo lectura) y nunca
/// deja una subida en cola: sin red las acciones de escritura se desactivan.
final deviceOnlineProvider = StreamProvider.autoDispose<bool>((ref) async* {
  yield await ref.read(networkInfoProvider).isConnected;
  yield* Connectivity().onConnectivityChanged.map(
        (result) =>
            result.isNotEmpty && !result.contains(ConnectivityResult.none),
      );
});

/// `true` salvo que se sepa que NO hay red (mientras carga se asume que sí).
bool isDeviceOnline(AsyncValue<bool> value) => value.valueOrNull ?? true;
