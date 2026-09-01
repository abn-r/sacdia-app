import '../entities/camporee.dart';

/// Club type IDs aligned with backend `isClubTypeIncludedInCamporee`.
abstract final class CamporeeClubTypeIds {
  static const adventurers = 1;
  static const pathfinders = 2;
  static const masterGuides = 3;
}

/// Resolves the section type used to list camporees.
///
/// Prefers the numeric id from the active grant. Falls back to the club type
/// name when the id is missing (same mapping as honors catalog).
int? resolveCamporeeListClubTypeId(int? clubTypeId, String? clubTypeName) {
  if (clubTypeId != null) return clubTypeId;

  final normalized = clubTypeName?.trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) return null;
  if (normalized.contains('aventur')) return CamporeeClubTypeIds.adventurers;
  if (normalized.contains('conquist')) return CamporeeClubTypeIds.pathfinders;
  if (normalized.contains('guia') || normalized.contains('guía')) {
    return CamporeeClubTypeIds.masterGuides;
  }
  return null;
}

bool camporeeIncludesClubType(Camporee camporee, int clubTypeId) {
  switch (clubTypeId) {
    case CamporeeClubTypeIds.adventurers:
      return camporee.includesAdventurers;
    case CamporeeClubTypeIds.pathfinders:
      return camporee.includesPathfinders;
    case CamporeeClubTypeIds.masterGuides:
      return camporee.includesMasterGuides;
    default:
      return false;
  }
}

/// Hides camporees that do not include [clubTypeId].
///
/// A null type (no section context) leaves the list unchanged so field-level
/// actors still see the territorial catalog.
List<Camporee> filterCamporeesForClubType(
  List<Camporee> camporees,
  int? clubTypeId,
) {
  if (clubTypeId == null) return camporees;
  return [
    for (final camporee in camporees)
      if (camporeeIncludesClubType(camporee, clubTypeId)) camporee,
  ];
}
