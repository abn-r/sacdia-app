import '../../domain/entities/honor_requirement.dart';

/// Number of checkable points in a requirement tree: every requirement plus
/// all of its nested sub-items.
///
/// The checklist tracks progress per point, while the catalog lists the
/// top-level requirements, so a honor with 11 requirements can have 26
/// points. Both screens use this count to label the same unit.
int countRequirementPoints(List<HonorRequirement> requirements) {
  var count = 0;
  for (final requirement in requirements) {
    count += 1 + countRequirementPoints(requirement.children);
  }
  return count;
}
