import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/network_info.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

/// ¿Hay red ahora? Primero la lectura puntual y luego los cambios.
///
/// El teléfono vinculado ve lo último guardado sin red (solo lectura) y nunca
/// deja una subida en cola: sin red las acciones de escritura se desactivan.
final deviceOnlineProvider = StreamProvider.autoDispose<bool>((ref) async* {
  yield await ref.read(networkInfoProvider).isConnected;
  yield* connectionChanges();
});

/// `true` salvo que se sepa que NO hay red (mientras carga se asume que sí).
bool isDeviceOnline(AsyncValue<bool> value) => value.value ?? true;
