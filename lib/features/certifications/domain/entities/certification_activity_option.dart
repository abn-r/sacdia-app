import 'package:equatable/equatable.dart';

/// Actividad que la persona puede enlazar a un componente `LINKED_ACTIVITY`.
class CertificationActivityOption extends Equatable {
  final int activityId;
  final String name;
  final DateTime? activityDate;
  final String? activityTypeName;
  final String? clubName;

  const CertificationActivityOption({
    required this.activityId,
    required this.name,
    this.activityDate,
    this.activityTypeName,
    this.clubName,
  });

  @override
  List<Object?> get props =>
      [activityId, name, activityDate, activityTypeName, clubName];
}
