import 'package:equatable/equatable.dart';

/// Estadísticas SLA de un proceso (investiture, evidence, camporee).
class SlaStat extends Equatable {
  final int pending;
  final double avgDays;
  final int overdue;

  const SlaStat({
    required this.pending,
    required this.avgDays,
    required this.overdue,
  });

  @override
  List<Object?> get props => [pending, avgDays, overdue];
}

/// Punto de datos de throughput semanal.
class ThroughputPoint extends Equatable {
  final String week;
  final int approved;
  final int rejected;

  const ThroughputPoint({
    required this.week,
    required this.approved,
    required this.rejected,
  });

  @override
  List<Object?> get props => [week, approved, rejected];
}

/// Etapa del pipeline de revisión.
class PipelineStage extends Equatable {
  final String stage;
  final int count;

  const PipelineStage({
    required this.stage,
    required this.count,
  });

  @override
  List<Object?> get props => [stage, count];
}

/// Entidad del dashboard SLA operativo del coordinador.
///
/// Devuelto por GET /admin/analytics/sla-dashboard.
class SlaDashboard extends Equatable {
  final SlaStat investiture;
  final SlaStat evidence;
  final SlaStat camporee;
  final List<ThroughputPoint> throughput;
  final List<PipelineStage> pipeline;

  const SlaDashboard({
    required this.investiture,
    required this.evidence,
    required this.camporee,
    required this.throughput,
    required this.pipeline,
  });

  /// Total de items pendientes en todos los procesos.
  int get totalPending =>
      investiture.pending + evidence.pending + camporee.pending;

  /// Total de items vencidos en todos los procesos.
  int get totalOverdue =>
      investiture.overdue + evidence.overdue + camporee.overdue;

  @override
  List<Object?> get props =>
      [investiture, evidence, camporee, throughput, pipeline];
}
