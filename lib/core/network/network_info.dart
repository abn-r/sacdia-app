import 'package:connectivity_plus/connectivity_plus.dart';

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
    final result = await connectivity.checkConnectivity();
    // connectivity_plus devuelve List<ConnectivityResult>
    // Verificamos que no contenga solo 'none' (sin conexión)
    return result.isNotEmpty && !result.contains(ConnectivityResult.none);
  }
}
