import 'package:equatable/equatable.dart';

/// Modelo para distritos eclesiásticos
class DistrictModel extends Equatable {
  final int districtId;
  final String name;
  final int localFieldId;

  const DistrictModel({
    required this.districtId,
    required this.name,
    required this.localFieldId,
  });

  /// Crea una instancia desde JSON
  factory DistrictModel.fromJson(Map<String, dynamic> json) {
    return DistrictModel(
      districtId: json['district_id'] as int,
      name: json['name'] as String,
      localFieldId: json['local_field_id'] as int,
    );
  }

  /// Convierte la instancia a JSON
  Map<String, dynamic> toJson() {
    return {
      'district_id': districtId,
      'name': name,
      'local_field_id': localFieldId,
    };
  }

  @override
  List<Object?> get props => [districtId, name, localFieldId];
}
