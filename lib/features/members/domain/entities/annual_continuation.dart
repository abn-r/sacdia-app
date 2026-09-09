import 'package:equatable/equatable.dart';

class SuggestedClass extends Equatable {
  final String status;
  final int? classId;
  final String? code;

  const SuggestedClass({
    required this.status,
    this.classId,
    this.code,
  });

  factory SuggestedClass.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const SuggestedClass(status: 'pending');
    }
    return SuggestedClass(
      status: json['status']?.toString() ?? 'pending',
      classId: int.tryParse(json['class_id']?.toString() ?? ''),
      code: json['code']?.toString(),
    );
  }

  @override
  List<Object?> get props => [status, classId, code];
}

/// Miembro no inscrito del año vigente para la sección destino.
class AnnualContinuation extends Equatable {
  final String userId;
  final String name;
  final int baseSectionId;
  final int ecclesiasticalYearId;
  final String annualStatus;
  final String? currentRole;
  final String eligibility;
  final String? blockedReason;
  final SuggestedClass suggestedClass;

  const AnnualContinuation({
    required this.userId,
    required this.name,
    required this.baseSectionId,
    required this.ecclesiasticalYearId,
    required this.annualStatus,
    this.currentRole,
    required this.eligibility,
    this.blockedReason,
    this.suggestedClass = const SuggestedClass(status: 'pending'),
  });

  bool get isBlocked => eligibility == 'blocked';

  @override
  List<Object?> get props => [
        userId,
        name,
        baseSectionId,
        ecclesiasticalYearId,
        annualStatus,
        currentRole,
        eligibility,
        blockedReason,
        suggestedClass,
      ];
}

class ContinuationUserResult extends Equatable {
  final String userId;
  final String outcome;
  final int? clubSectionId;
  final int? ecclesiasticalYearId;
  final int? enrollmentId;
  final String? errorCode;

  const ContinuationUserResult({
    required this.userId,
    required this.outcome,
    this.clubSectionId,
    this.ecclesiasticalYearId,
    this.enrollmentId,
    this.errorCode,
  });

  @override
  List<Object?> get props => [
        userId,
        outcome,
        clubSectionId,
        ecclesiasticalYearId,
        enrollmentId,
        errorCode,
      ];
}

class ContinuationBatchResult extends Equatable {
  final List<ContinuationUserResult> results;

  const ContinuationBatchResult({this.results = const []});

  factory ContinuationBatchResult.fromJson(Map<String, dynamic> json) {
    final raw = json['results'];
    if (raw is! List) {
      return const ContinuationBatchResult();
    }
    return ContinuationBatchResult(
      results: raw
          .whereType<Map>()
          .map(
            (row) => ContinuationUserResult(
              userId: row['user_id']?.toString() ?? '',
              outcome: row['outcome']?.toString() ?? 'failed',
              clubSectionId:
                  int.tryParse(row['club_section_id']?.toString() ?? ''),
              ecclesiasticalYearId: int.tryParse(
                row['ecclesiastical_year_id']?.toString() ?? '',
              ),
              enrollmentId:
                  int.tryParse(row['enrollment_id']?.toString() ?? ''),
              errorCode: row['error_code']?.toString(),
            ),
          )
          .toList(),
    );
  }

  int get enrolledCount =>
      results.where((row) => row.outcome == 'enrolled').length;

  int get alreadyEnrolledCount =>
      results.where((row) => row.outcome == 'already_enrolled').length;

  int get blockedCount =>
      results.where((row) => row.outcome == 'blocked').length;

  int get failedCount =>
      results.where((row) => row.outcome == 'failed').length;

  bool get hasPartialFailure => blockedCount > 0 || failedCount > 0;

  @override
  List<Object?> get props => [results];
}
