import '../entities/virtual_card.dart';

abstract class VirtualCardRepository {
  Future<VirtualCard> getRemoteCard();

  Future<VirtualCard?> getCachedCard(String userId);

  Future<void> saveCachedCard(VirtualCard card);

  /// Descarga el PDF de la credencial desde el backend.
  /// Devuelve los bytes crudos del archivo.
  Future<List<int>> getCardPdf();
}
