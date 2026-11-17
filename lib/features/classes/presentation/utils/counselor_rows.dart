import '../../domain/entities/class_counselor_assignment.dart';
import '../../domain/entities/progressive_class.dart';

/// The two roles managed from the counselors screen. The backend also has a
/// `substitute` responsibility; the screen does not offer it.
const String kPrimaryResponsibility = 'primary';
const String kAssistantResponsibility = 'assistant';

/// One class of the section with who looks after it.
class ClassCounselorRow {
  final int classId;
  final String name;

  /// Counselor (`responsibility_type = primary`).
  final ClassCounselorAssignment? primary;

  /// Sub-counselor (`responsibility_type = assistant`).
  final ClassCounselorAssignment? assistant;

  const ClassCounselorRow({
    required this.classId,
    required this.name,
    this.primary,
    this.assistant,
  });

  bool get hasCounselor => primary != null;
  bool get hasAnyAssignment => primary != null || assistant != null;
}

String _normalizeRole(String? role) =>
    role?.trim().toLowerCase().replaceAll(RegExp(r'[\s_]+'), '-') ?? '';

String _normalizeName(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll('á', 'a')
    .replaceAll('é', 'e')
    .replaceAll('í', 'i')
    .replaceAll('ó', 'o')
    .replaceAll('ú', 'u')
    .replaceAll('ü', 'u')
    .replaceAll('ñ', 'n');

/// Position of a class by name, from the youngest to the oldest.
int classOrderOf(String name) {
  switch (_normalizeName(name)) {
    case 'amigo':
      return 1;
    case 'companero':
      return 2;
    case 'explorador':
      return 3;
    case 'orientador':
      return 4;
    case 'viajero':
      return 5;
    case 'guia':
      return 6;
    default:
      return 999;
  }
}

/// Name to show for a person; their e-mail or id when the name is empty.
String counselorPersonName(ClassCounselorPerson person, String fallback) {
  final displayName = person.displayName.trim();
  if (displayName.isNotEmpty) return displayName;
  if (person.email.trim().isNotEmpty) return person.email.trim();
  return fallback;
}

/// One row per class. Every class of the catalog gets a row, with or without
/// assignments; a class that only shows up in an assignment is added too.
/// Rows go from the youngest class to the oldest.
List<ClassCounselorRow> buildCounselorRows(
  List<ProgressiveClass> classes,
  List<ClassCounselorAssignment> assignments,
) {
  final names = <int, String>{
    for (final c in classes) c.id: c.name,
    for (final a in assignments) a.classId: a.clazz.name,
  };
  // The server may order the assignments; keep the first of each role.
  ClassCounselorAssignment? pick(int classId, String responsibility) {
    for (final a in assignments) {
      if (a.classId == classId &&
          a.active &&
          _normalizeRole(a.responsibilityType) == responsibility) {
        return a;
      }
    }
    return null;
  }

  final rows = [
    for (final entry in names.entries)
      ClassCounselorRow(
        classId: entry.key,
        name: entry.value,
        primary: pick(entry.key, kPrimaryResponsibility),
        assistant: pick(entry.key, kAssistantResponsibility),
      ),
  ]..sort((a, b) {
      final byOrder = classOrderOf(a.name).compareTo(classOrderOf(b.name));
      return byOrder != 0 ? byOrder : a.name.compareTo(b.name);
    });
  return rows;
}

/// Everything needed to turn the current assignments of a class into the
/// ones the user picked: who to revoke first, then who to create.
class AssignmentPlan {
  /// Assignments to revoke (a person that goes away or changes role).
  final List<ClassCounselorAssignment> revokes;

  /// `(userId, responsibility)` to create after the revokes.
  final List<(String, String)> creates;

  const AssignmentPlan({required this.revokes, required this.creates});

  bool get isEmpty => revokes.isEmpty && creates.isEmpty;
}

/// Plan to move [row] from its current people to [counselorId] and
/// [assistantId] (null = nobody). A person cannot be changed with PATCH, so
/// replacing someone means revoking and creating; everything is revoked
/// first so the "only one per role" rule never trips.
AssignmentPlan planAssignmentChange(
  ClassCounselorRow row, {
  required String? counselorId,
  required String? assistantId,
}) {
  final revokes = <ClassCounselorAssignment>[];
  final creates = <(String, String)>[];

  void plan(
    ClassCounselorAssignment? current,
    String? target,
    String responsibility,
  ) {
    if (current != null && current.userId == target) return;
    if (current != null) revokes.add(current);
    if (target != null) creates.add((target, responsibility));
  }

  plan(row.primary, counselorId, kPrimaryResponsibility);
  plan(row.assistant, assistantId, kAssistantResponsibility);
  return AssignmentPlan(revokes: revokes, creates: creates);
}
