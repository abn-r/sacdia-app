import '../../data/models/class_model.dart';
import '../../data/models/club_section_model.dart';

const int adventurersMinAge = 4;
const int adventurersMaxAge = 9;
const int pathfindersMinAge = 10;
const int pathfindersMaxAge = 15;
const int masterGuidesMinAge = 16;

int? calculateAgeFromBirthdate(DateTime? birthdate, {DateTime? today}) {
  if (birthdate == null) return null;

  final current = today ?? DateTime.now();
  var age = current.year - birthdate.year;
  final birthdayReached = current.month > birthdate.month ||
      (current.month == birthdate.month && current.day >= birthdate.day);

  if (!birthdayReached) age -= 1;
  return age >= 0 ? age : null;
}

ClubSectionModel? recommendedClubSectionForAge(
  List<ClubSectionModel> sections,
  int? age,
) {
  if (age == null) return null;

  bool Function(ClubSectionModel section)? matcher;
  if (age >= adventurersMinAge && age <= adventurersMaxAge) {
    matcher = isAdventurersSection;
  } else if (age >= pathfindersMinAge && age <= pathfindersMaxAge) {
    matcher = isPathfindersSection;
  } else if (age >= masterGuidesMinAge) {
    matcher = isMasterGuidesSection;
  }

  if (matcher == null) return null;

  for (final section in sections) {
    if (matcher(section)) return section;
  }
  return null;
}

ClassModel? recommendedProgressiveClassForAge(
  List<ClassModel> classes,
  int? age,
) {
  if (age == null) return null;

  final eligible = classes.where((classModel) {
    final minAge = classModel.minAge;
    if (minAge == null || age < minAge) return false;

    final maxAge = classModel.maxAge;
    return maxAge == null || age <= maxAge;
  }).toList()
    ..sort((a, b) {
      final minAgeCompare = b.minAge!.compareTo(a.minAge!);
      if (minAgeCompare != 0) return minAgeCompare;
      return a.id.compareTo(b.id);
    });

  return eligible.isEmpty ? null : eligible.first;
}

bool isAdventurersSection(ClubSectionModel section) {
  final name = section.clubTypeName?.toLowerCase();
  return section.clubTypeSlug == 'adventurers' ||
      (name?.contains('aventurero') ?? false);
}

bool isPathfindersSection(ClubSectionModel section) {
  final name = section.clubTypeName?.toLowerCase();
  return section.clubTypeSlug == 'pathfinders' ||
      (name?.contains('conquistador') ?? false);
}

bool isMasterGuidesSection(ClubSectionModel section) {
  final name = section.clubTypeName?.toLowerCase();
  return section.clubTypeSlug == 'master_guild' ||
      section.clubTypeSlug == 'master_guilds' ||
      (name?.contains('guía') ?? false) ||
      (name?.contains('guia') ?? false) ||
      (name?.contains('master') ?? false);
}
