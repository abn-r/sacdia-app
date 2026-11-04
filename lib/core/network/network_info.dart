import 'package:connectivity_plus/connectivity_plus.dart';

/// ¿[results] (de `connectivity_plus`) significa que hay red? La lista vacía
/// o que solo contenga [ConnectivityResult.none] es «sin conexión».
bool hasConnection(List<ConnectivityResult> results) =>
    results.isNotEmpty && !results.contains(ConnectivityResult.none);

/// Cambios de conectividad como `true`/`false`, sin repetir el mismo valor.
/// Lo escuchan quienes reaccionan a recuperar la red (p. ej. la raíz de la
/// app para refrescar una autorización obsoleta).
Stream<bool> connectionChanges({Connectivity? connectivity}) =>
    (connectivity ?? Connectivity())
        .onConnectivityChanged
        .map(hasConnection)
        .distinct();

/// Abstracción para verificar la conectividad de red
abstract class NetworkInfo {
  Future<bool> get isConnected;
}

/// Implementación de NetworkInfo usando el paquete connectivity_plus
class NetworkInfoImpl implements NetworkInfo {
  final Connectivity connectivity;

  NetworkInfoImpl({Connectivity? connectivity})
      : connectivity = connectivity ?? Connectivity();

  @override
  Future<bool> get isConnected async {
    // connectivity_plus devuelve List<ConnectivityResult>
    return hasConnection(await connectivity.checkConnectivity());
  }
}
