import '../../domain/entities/yearbook_entry.dart';
import 'json_parsing.dart';

class YearbookEntryModel extends YearbookEntry {
  const YearbookEntryModel({
    required super.enrollmentId,
    required super.userId,
    required super.classId,
    super.className,
    required super.ecclesiasticalYearId,
  });

  factory YearbookEntryModel.fromJson(Map<String, dynamic> json) {
    return YearbookEntryModel(
      enrollmentId: asInt(json['enrollment_id']),
      userId: json['user_id']?.toString() ?? '',
      classId: asInt(json['class_id']),
      className: asStringOrNull(json['class_name']),
      ecclesiasticalYearId: asInt(json['ecclesiastical_year_id']),
    );
  }
}
