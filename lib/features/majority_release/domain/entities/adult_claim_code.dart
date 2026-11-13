import 'package:equatable/equatable.dart';

/// Código de acceso de un solo uso para que un adulto liberado SIN credenciales
/// reclame su cuenta (`purpose: adult_claim`). El texto en claro solo viaja en
/// la respuesta que lo emite: la app lo muestra una vez y no lo guarda.
class IssuedAdultClaimCode extends Equatable {
  final String code;
  final DateTime expiresAt;

  const IssuedAdultClaimCode({required this.code, required this.expiresAt});

  @override
  List<Object?> get props => [code, expiresAt];
}
