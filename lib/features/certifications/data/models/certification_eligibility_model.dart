import 'package:equatable/equatable.dart';

import '../../domain/entities/certification_activity_option.dart';
import '../../domain/entities/certification_eligibility.dart';

/// `GET .../certifications/:id/eligibility`.
class CertificationEligibilityModel extends Equatable {
  final bool eligible;
  final List<CertificationEligibilityRule> rules;
  final String? reasonCode;

  const CertificationEligibilityModel({
    required this.eligible,
    this.rules = const [],
    this.reasonCode,
  });

  factory CertificationEligibilityModel.fromJson(Map<String, dynamic> json) {
    final rawRules = json['rules'];
    return CertificationEligibilityModel(
      eligible: json['eligible'] == true,
      reasonCode: json['reason_code'] as String?,
      rules: [
        if (rawRules is List)
          for (final rule in rawRules)
            if (rule is Map)
              CertificationEligibilityRule(
                ruleId: (rule['eligibility_rule_id'] as num?)?.toInt(),
                type: certificationEligibilityRuleTypeFromWire(
                  rule['type'] as String?,
                ),
                satisfied: rule['satisfied'] == true,
                reasonCode: rule['reason_code'] as String?,
              ),
      ],
    );
  }

  CertificationEligibility toEntity() => CertificationEligibility(
        eligible: eligible,
        rules: rules,
        reasonCode: reasonCode,
      );

  @override
  List<Object?> get props => [eligible, rules, reasonCode];
}

/// Una opción de `.../components/:id/activity-options`.
class CertificationActivityOptionModel extends Equatable {
  final int activityId;
  final String name;
  final DateTime? activityDate;
  final String? activityTypeName;
  final String? clubName;

  const CertificationActivityOptionModel({
    required this.activityId,
    required this.name,
    this.activityDate,
    this.activityTypeName,
    this.clubName,
  });

  factory CertificationActivityOptionModel.fromJson(Map<String, dynamic> json) {
    final date = json['activity_date'];
    return CertificationActivityOptionModel(
      activityId: (json['activity_id'] as num).toInt(),
      name: json['name'] as String? ?? '',
      activityDate: date is String ? _calendarDate(date) : null,
      activityTypeName: json['activity_type_name'] as String?,
      clubName: json['club_name'] as String?,
    );
  }

  CertificationActivityOption toEntity() => CertificationActivityOption(
        activityId: activityId,
        name: name,
        activityDate: activityDate,
        activityTypeName: activityTypeName,
        clubName: clubName,
      );

  @override
  List<Object?> get props =>
      [activityId, name, activityDate, activityTypeName, clubName];
}

/// `activities.activity_date` is a date column; the API sends it as UTC
/// midnight ("2026-04-02T00:00:00.000Z"). Read the calendar date as-is so it
/// is not shown a day early west of UTC.
DateTime? _calendarDate(String raw) {
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return null;
  return DateTime(parsed.year, parsed.month, parsed.day);
}
