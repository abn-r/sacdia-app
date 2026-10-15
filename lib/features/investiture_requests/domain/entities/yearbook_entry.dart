import 'package:equatable/equatable.dart';

/// Inscripción del anuario de investiduras de una sección.
class YearbookEntry extends Equatable {
  const YearbookEntry({
    required this.enrollmentId,
    required this.userId,
    required this.classId,
    this.className,
    required this.ecclesiasticalYearId,
  });

  final int enrollmentId;
  final String userId;
  final int classId;
  final String? className;
  final int ecclesiasticalYearId;

  @override
  List<Object?> get props =>
      [enrollmentId, userId, classId, className, ecclesiasticalYearId];
}
