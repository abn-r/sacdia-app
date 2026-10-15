import '../../domain/entities/own_investiture_entry.dart';
import '../../domain/entities/person_status.dart';
import 'json_parsing.dart';

class OwnInvestitureEntryModel extends OwnInvestitureEntry {
  const OwnInvestitureEntryModel({
    required super.personId,
    required super.userId,
    required super.classId,
    super.className,
    required super.clubSectionId,
    required super.ecclesiasticalYearId,
    required super.investitureDate,
    required super.status,
    super.rejectionReason,
    super.systemReason,
    super.personText,
    super.authorizationComment,
  });

  factory OwnInvestitureEntryModel.fromJson(Map<String, dynamic> json) {
    return OwnInvestitureEntryModel(
      personId: json['person_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      classId: asInt(json['class_id']),
      className: asStringOrNull(json['class_name']),
      clubSectionId: asInt(json['club_section_id']),
      ecclesiasticalYearId: asInt(json['ecclesiastical_year_id']),
      investitureDate: parseCivilDate(json['investiture_date']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      status: PersonStatus.fromString(json['status']?.toString()),
      rejectionReason: asStringOrNull(json['rejection_reason']),
      systemReason: asStringOrNull(json['system_reason']),
      personText: asStringOrNull(json['person_text']),
      authorizationComment: asStringOrNull(json['authorization_comment']),
    );
  }
}
