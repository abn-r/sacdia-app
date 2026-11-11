import 'package:equatable/equatable.dart';

/// How strictly the server treats a requirement. The server switches modes;
/// the app only renders them.
enum RequirementMode {
  info,
  warn,
  block;

  /// An unknown value is `info`: the least intrusive reading (fails safe).
  static RequirementMode parse(Object? raw) =>
      switch (raw?.toString().toUpperCase()) {
        'WARN' => RequirementMode.warn,
        'BLOCK' => RequirementMode.block,
        _ => RequirementMode.info,
      };
}

/// Whether the person satisfies a requirement.
enum RequirementStatus {
  met,
  pendingReview,
  missing;

  /// An unknown value is `missing` (fails safe: never claims «met»).
  static RequirementStatus parse(Object? raw) =>
      switch (raw?.toString().toUpperCase()) {
        'MET' => RequirementStatus.met,
        'PENDING_REVIEW' => RequirementStatus.pendingReview,
        _ => RequirementStatus.missing,
      };
}

/// `requirements[]` item: what a service role will ask of the person.
class RoleRequirement extends Equatable {
  const RoleRequirement({
    required this.role,
    this.type = counselorTraining,
    this.mode = RequirementMode.info,
    this.status = RequirementStatus.missing,
    this.enforced = false,
  });

  /// The only requirement type the contract publishes today.
  static const counselorTraining = 'COUNSELOR_TRAINING';

  final String role;
  final String type;
  final RequirementMode mode;
  final RequirementStatus status;
  final bool enforced;

  bool get isMet => status == RequirementStatus.met;

  /// The server removes the role from `allowed_roles` in this case.
  bool get blocksAssignment =>
      mode == RequirementMode.block && enforced && !isMet;

  /// Not met in WARN or BLOCK mode (enforced or not): worth flagging in the UI.
  bool get isFlagged => mode != RequirementMode.info && !isMet;

  /// Strictness used to pick the note of the detail: BLOCK enforced > WARN
  /// (BLOCK not enforced behaves like WARN) > INFO.
  int get severity => switch (mode) {
        RequirementMode.block => enforced ? 2 : 1,
        RequirementMode.warn => 1,
        RequirementMode.info => 0,
      };

  @override
  List<Object?> get props => [role, type, mode, status, enforced];
}

enum CredentialStatus {
  approved,
  pendingReview,
  rejected;

  /// An unknown value is `rejected`: never shown as an approved constancia.
  static CredentialStatus parse(Object? raw) =>
      switch (raw?.toString().toUpperCase()) {
        'APPROVED' => CredentialStatus.approved,
        'PENDING_REVIEW' => CredentialStatus.pendingReview,
        _ => CredentialStatus.rejected,
      };
}

/// `credentials[]` item of the detail (a «constancia de consejería»).
class RoleCandidateCredential extends Equatable {
  const RoleCandidateCredential({
    this.type = RoleRequirement.counselorTraining,
    required this.status,
    this.completedAt,
    this.expiresAt,
  });

  final String type;
  final CredentialStatus status;
  final DateTime? completedAt;
  final DateTime? expiresAt;

  @override
  List<Object?> get props => [type, status, completedAt, expiresAt];
}
