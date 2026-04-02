import 'package:equatable/equatable.dart';

/// Modelo para años eclesiásticos
class EcclesiasticalYearModel extends Equatable {
  final int ecclesiasticalYearId;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final bool active;

  const EcclesiasticalYearModel({
    required this.ecclesiasticalYearId,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.active,
  });

  /// Crea una instancia desde JSON
  factory EcclesiasticalYearModel.fromJson(Map<String, dynamic> json) {
    return EcclesiasticalYearModel(
      ecclesiasticalYearId: json['ecclesiastical_year_id'] as int,
      name: (json['name'] as String?) ?? '',
      startDate: json['start_date'] != null
          ? DateTime.parse(json['start_date'] as String)
          : DateTime(2000),
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'] as String)
          : DateTime(2000),
      active: (json['active'] as bool?) ?? false,
    );
  }

  /// Convierte la instancia a JSON
  Map<String, dynamic> toJson() {
    return {
      'ecclesiastical_year_id': ecclesiasticalYearId,
      'name': name,
      'start_date': startDate.toIso8601String().split('T').first,
      'end_date': endDate.toIso8601String().split('T').first,
      'active': active,
    };
  }

  @override
  List<Object?> get props => [
        ecclesiasticalYearId,
        name,
        startDate,
        endDate,
        active,
      ];
}
