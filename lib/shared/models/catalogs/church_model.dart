import 'package:equatable/equatable.dart';

/// Modelo para iglesias
class ChurchModel extends Equatable {
  final int churchId;
  final String name;
  final int districtId;

  const ChurchModel({
    required this.churchId,
    required this.name,
    required this.districtId,
  });

  /// Crea una instancia desde JSON
  factory ChurchModel.fromJson(Map<String, dynamic> json) {
    return ChurchModel(
      churchId: json['church_id'] as int,
      name: json['name'] as String,
      districtId: json['district_id'] as int,
    );
  }

  /// Convierte la instancia a JSON
  Map<String, dynamic> toJson() {
    return {
      'church_id': churchId,
      'name': name,
      'district_id': districtId,
    };
  }

  @override
  List<Object?> get props => [churchId, name, districtId];
}
