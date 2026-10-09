import '../../domain/entities/investiture_resolution.dart';
import '../../domain/entities/person_status.dart';
import 'investiture_request_model.dart';
import 'json_parsing.dart';

class InvestitureResolutionModel extends InvestitureResolution {
  const InvestitureResolutionModel({
    required super.requestId,
    required super.invested,
    required super.rejectedByPerson,
    required super.rejectedBySystem,
    required super.retired,
    required super.blocked,
    required super.alreadyResolved,
  });

  factory InvestitureResolutionModel.fromJson(Map<String, dynamic> json) {
    List<RequestPersonModel> people(String key) => asJsonMapList(json[key])
        .map(RequestPersonModel.fromJson)
        .toList(growable: false);

    return InvestitureResolutionModel(
      requestId: json['request_id']?.toString() ?? '',
      invested: people('invested'),
      rejectedByPerson: people('rejected_by_person'),
      rejectedBySystem: people('rejected_by_system'),
      retired: people('retired'),
      blocked: asJsonMapList(json['blocked'])
          .map(
            (b) => BlockedDecision(
              personId: b['person_id']?.toString() ?? '',
              code: b['code']?.toString() ?? '',
            ),
          )
          .toList(growable: false),
      alreadyResolved: asJsonMapList(json['already_resolved'])
          .map(
            (a) => AlreadyResolvedDecision(
              personId: a['person_id']?.toString() ?? '',
              status: PersonStatus.fromString(a['status']?.toString()),
            ),
          )
          .toList(growable: false),
    );
  }
}
