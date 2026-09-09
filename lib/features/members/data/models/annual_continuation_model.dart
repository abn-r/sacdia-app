import '../../domain/entities/annual_continuation.dart';

List<AnnualContinuationModel> unwrapAnnualContinuationItems(
  dynamic responseData,
) {
  final raw = _unwrapList(responseData);
  return raw.map(AnnualContinuationModel.fromJson).toList();
}

List<Map<String, dynamic>> _unwrapList(dynamic responseData) {
  if (responseData is List) {
    return responseData.whereType<Map>().map((row) {
      return Map<String, dynamic>.from(row);
    }).toList();
  }
  if (responseData is Map) {
    final data = responseData['data'];
    if (data is List) {
      return data.whereType<Map>().map(Map<String, dynamic>.from).toList();
    }
    if (data is Map) {
      final nested =
          data['data'] ?? data['members'] ?? data['items'] ?? data['results'];
      if (nested is List) {
        return nested.whereType<Map>().map(Map<String, dynamic>.from).toList();
      }
    }
  }
  return const [];
}

class AnnualContinuationModel extends AnnualContinuation {
  const AnnualContinuationModel({
    required super.userId,
    required super.name,
    required super.baseSectionId,
    required super.ecclesiasticalYearId,
    required super.annualStatus,
    super.currentRole,
    required super.eligibility,
    super.blockedReason,
    super.suggestedClass,
  });

  factory AnnualContinuationModel.fromJson(Map<String, dynamic> json) {
    final suggested = json['suggested_class'];
    final suggestedMap =
        suggested is Map ? Map<String, dynamic>.from(suggested) : null;
    return AnnualContinuationModel(
      userId: json['user_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      baseSectionId: int.tryParse(json['base_section_id']?.toString() ?? '') ?? 0,
      ecclesiasticalYearId:
          int.tryParse(json['ecclesiastical_year_id']?.toString() ?? '') ?? 0,
      annualStatus: json['annual_status']?.toString() ?? 'not_enrolled',
      currentRole: json['current_role']?.toString(),
      eligibility: json['eligibility']?.toString() ?? 'eligible',
      blockedReason: json['blocked_reason']?.toString(),
      suggestedClass: SuggestedClass.fromJson(suggestedMap),
    );
  }

  AnnualContinuation toEntity() => AnnualContinuation(
        userId: userId,
        name: name,
        baseSectionId: baseSectionId,
        ecclesiasticalYearId: ecclesiasticalYearId,
        annualStatus: annualStatus,
        currentRole: currentRole,
        eligibility: eligibility,
        blockedReason: blockedReason,
        suggestedClass: suggestedClass,
      );
}
