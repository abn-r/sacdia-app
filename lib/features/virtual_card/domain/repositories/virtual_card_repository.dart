import '../entities/virtual_card.dart';

abstract class VirtualCardRepository {
  Future<VirtualCard> getRemoteCard();

  Future<VirtualCard?> getCachedCard(String userId);

  Future<void> saveCachedCard(VirtualCard card);
}
