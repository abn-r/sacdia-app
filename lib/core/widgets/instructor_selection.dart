import 'package:easy_localization/easy_localization.dart';
import 'package:equatable/equatable.dart';

enum InstructorKind { none, user, external }

/// Who taught a honor: nobody, a person of the member's Local Field, or a
/// name typed by hand (not verified, may be someone outside SACDIA).
///
/// Shared by every flow that asks for an instructor. It knows nothing about
/// batches or honors: each feature maps it to its own payload.
class InstructorSelection extends Equatable {
  const InstructorSelection.none()
      : kind = InstructorKind.none,
        userId = null,
        displayName = '',
        photoUrl = null;

  const InstructorSelection.user({
    required String id,
    required this.displayName,
    this.photoUrl,
  })  : kind = InstructorKind.user,
        userId = id;

  const InstructorSelection.external(String name)
      : kind = InstructorKind.external,
        userId = null,
        displayName = name,
        photoUrl = null;

  final InstructorKind kind;

  /// Set only for [InstructorKind.user].
  final String? userId;

  /// The person's name, or the typed name for [InstructorKind.external].
  final String displayName;
  final String? photoUrl;

  bool get isNone => kind == InstructorKind.none;
  bool get isUser => kind == InstructorKind.user;
  bool get isExternal => kind == InstructorKind.external;

  /// `{ "user_id": ..., "display_name": ..., "photo_url": ... }` as the
  /// `GET /instructor-candidates` endpoint answers.
  static InstructorSelection? tryParseCandidate(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['user_id'];
    final name = raw['display_name'];
    if (id is! String || id.isEmpty || name is! String || name.trim().isEmpty) {
      return null;
    }
    final photo = raw['photo_url'];
    return InstructorSelection.user(
      id: id,
      displayName: name.trim(),
      photoUrl: photo is String && photo.isNotEmpty ? photo : null,
    );
  }

  @override
  List<Object?> get props => [kind, userId, displayName, photoUrl];
}

/// Length rules the API applies to the typed name and to the search text.
abstract final class InstructorRules {
  /// The search answers `[]` below 3 characters in total or 2 per word.
  static const int minSearchChars = 3;
  static const int minSearchWordChars = 2;

  /// A typed name is 3 to 150 characters once trimmed.
  static const int minNameChars = 3;
  static const int maxNameChars = 150;

  /// Trims and collapses inner whitespace, like the API does.
  static String normalize(String raw) =>
      raw.trim().replaceAll(RegExp(r'\s+'), ' ');

  /// Whether [raw] is worth sending to the search endpoint.
  static bool isSearchable(String raw) {
    final text = normalize(raw);
    if (text.length < minSearchChars) return false;
    return text.split(' ').every((w) => w.length >= minSearchWordChars);
  }

  /// The typed name as the API would keep it, or null if it cannot be used.
  static String? freeName(String raw) {
    final text = normalize(raw);
    if (text.length < minNameChars || text.length > maxNameChars) return null;
    return text;
  }
}

/// Business codes of the instructor rules, shared by both flows.
abstract final class InstructorErrorCode {
  static const invalid = 'HONOR_INSTRUCTOR_INVALID';
  static const self = 'HONOR_INSTRUCTOR_SELF';
  static const ambiguous = 'HONOR_INSTRUCTOR_AMBIGUOUS';

  static const Set<String> all = {invalid, self, ambiguous};

  /// Copy for the instructor field when the API refused the person, or null
  /// when [code] is not about the instructor.
  static String? fieldMessage(String? code) => switch (code) {
        invalid => 'instructor.error_invalid'.tr(),
        self => 'instructor.error_self'.tr(),
        ambiguous => 'instructor.error_generic'.tr(),
        _ => null,
      };
}
