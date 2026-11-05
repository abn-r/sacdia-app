import 'package:equatable/equatable.dart';

import '../../domain/entities/progressive_class.dart';
import '../roadmap/data/roadmap_mapper.dart';

/// Club types in the order «Clases por club» lists them:
/// Aventureros, Conquistadores, Guías Mayores.
const List<int> kClassCatalogClubTypeOrder = [1, 2, 3];

/// The user's standing in one class.
enum ClassCatalogStatus { invested, inProgress, expired, notInvested }

/// One class of the catalog with the user's status.
class ClassCatalogEntry extends Equatable {
  const ClassCatalogEntry({
    required this.classId,
    required this.name,
    required this.clubTypeId,
    required this.status,
    this.imageUrl,
    this.minAge,
    this.maxAge,
    this.year,
    this.isCurrent = false,
  });

  final int classId;
  final String name;
  final int clubTypeId;
  final String? imageUrl;

  /// First age of the class. Null when the catalog has no age for it.
  final int? minAge;

  /// Last age of the class (inclusive). Null means open-ended («desde»).
  final int? maxAge;

  final ClassCatalogStatus status;

  /// Investiture year when [status] is invested; the ecclesiastical year of
  /// the enrollment otherwise. Null when unknown or not enrolled.
  final String? year;

  /// Same class Mis Clases shows under «Clase actual».
  final bool isCurrent;

  @override
  List<Object?> get props => [
        classId,
        name,
        clubTypeId,
        imageUrl,
        minAge,
        maxAge,
        status,
        year,
        isCurrent,
      ];
}

/// The classes of one club type, youngest first.
class ClassCatalogSection extends Equatable {
  const ClassCatalogSection({required this.clubTypeId, required this.entries});

  final int clubTypeId;
  final List<ClassCatalogEntry> entries;

  int? get minAge => entries.first.minAge;

  /// Null when the last class of the club is open-ended.
  int? get maxAge => entries.last.maxAge;

  @override
  List<Object?> get props => [clubTypeId, entries];
}

/// The class Mis Clases shows as «Clase actual»: the most recent enrollment
/// that is not expired. [enrolled] comes ordered by enrollment date, newest
/// first, from `GET /users/:id/classes`.
ProgressiveClass? currentClassOf(List<ProgressiveClass> enrolled) {
  for (final cls in enrolled) {
    if (!cls.isExpired) return cls;
  }
  return null;
}

/// Groups the enabled catalog by club type and merges the user's enrollments.
///
/// [catalog] is `GET /classes` (only active classes inside their availability
/// window), ordered by club type and display order. Ages: a class runs from
/// its minimum age until the year before the next class (in the whole list)
/// that starts older; the last one is open-ended.
List<ClassCatalogSection> buildClassCatalog({
  required List<ProgressiveClass> catalog,
  required List<ProgressiveClass> enrolled,
}) {
  final byType = <int, List<ProgressiveClass>>{};
  for (final cls in catalog) {
    byType.putIfAbsent(cls.clubTypeId, () => []).add(cls);
  }
  final ordered = [
    for (final typeId in kClassCatalogClubTypeOrder) ...?byType[typeId],
  ];
  final minAges = [for (final cls in ordered) resolveClassMinimumAge(cls)];

  final enrollmentsById = <int, List<ProgressiveClass>>{};
  for (final cls in enrolled) {
    enrollmentsById.putIfAbsent(cls.id, () => []).add(cls);
  }
  final currentId = currentClassOf(enrolled)?.id;

  final entries = <ClassCatalogEntry>[];
  for (var i = 0; i < ordered.length; i++) {
    final cls = ordered[i];
    final minAge = minAges[i];
    int? maxAge;
    if (minAge != null) {
      for (var j = i + 1; j < ordered.length; j++) {
        final next = minAges[j];
        if (next != null && next > minAge) {
          maxAge = next - 1;
          break;
        }
      }
    }

    final (status, year) = _statusOf(enrollmentsById[cls.id] ?? const []);
    entries.add(ClassCatalogEntry(
      classId: cls.id,
      name: cls.name,
      clubTypeId: cls.clubTypeId,
      imageUrl: cls.imageUrl,
      minAge: minAge,
      maxAge: maxAge,
      status: status,
      year: year,
      isCurrent: cls.id == currentId,
    ));
  }

  return [
    for (final typeId in kClassCatalogClubTypeOrder)
      if (entries.any((e) => e.clubTypeId == typeId))
        ClassCatalogSection(
          clubTypeId: typeId,
          entries: entries.where((e) => e.clubTypeId == typeId).toList(),
        ),
  ];
}

/// An invested enrollment wins over any other year of the same class;
/// otherwise the newest enrollment decides.
(ClassCatalogStatus, String?) _statusOf(List<ProgressiveClass> enrollments) {
  if (enrollments.isEmpty) return (ClassCatalogStatus.notInvested, null);

  for (final enrollment in enrollments) {
    if (enrollment.isInvested) {
      final year = enrollment.investitureDate?.year.toString() ??
          _lastYear(enrollment.ecclesiasticalYearLabel);
      return (ClassCatalogStatus.invested, year);
    }
  }

  final latest = enrollments.first;
  return (
    latest.isExpired
        ? ClassCatalogStatus.expired
        : ClassCatalogStatus.inProgress,
    latest.ecclesiasticalYearLabel,
  );
}

/// «2025–2026» → «2026»: a class is invested at the end of its year.
String? _lastYear(String? label) {
  if (label == null) return null;
  final years = RegExp(r'\d{4}').allMatches(label).toList();
  return years.isEmpty ? null : years.last.group(0);
}
