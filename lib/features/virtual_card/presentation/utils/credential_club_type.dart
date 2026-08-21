import '../../../../core/theme/club_type.dart';
import '../../../auth/domain/entities/authorization_snapshot.dart';
import '../../domain/entities/virtual_card.dart';

/// Picks the club type that the virtual credential should show.
///
/// The section switcher changes operational context (activities, roster).
/// The credential is personal identity: among the user's *active* assignments,
/// use the highest program in the JA cycle:
/// Guías Mayores > Conquistadores > Aventureros.
String? resolveCredentialClubType(List<AuthorizationGrant> assignments) {
  AuthorizationGrant? best;
  var bestRank = -1;

  for (final grant in assignments) {
    if (!grant.isActive) continue;
    final rank = _clubTypeCycleRank(clubTypeFromName(grant.clubTypeName));
    if (rank > bestRank) {
      bestRank = rank;
      best = grant;
    }
  }

  final name = best?.clubTypeName?.trim();
  if (name == null || name.isEmpty) return null;
  return name;
}

VirtualCard applyCredentialIdentity({
  required VirtualCard card,
  required List<AuthorizationGrant> assignments,
}) {
  final identityType = resolveCredentialClubType(assignments);
  if (identityType == null) return card;
  if (card.sectionName == identityType) return card;
  return card.copyWith(sectionName: identityType);
}

int _clubTypeCycleRank(ClubType? type) {
  switch (type) {
    case ClubType.guiasMayores:
      return 2;
    case ClubType.conquistadores:
      return 1;
    case ClubType.aventureros:
      return 0;
    case null:
      return -1;
  }
}
