import 'package:equatable/equatable.dart';
import '../../domain/entities/sla_dashboard.dart';

class SlaStatModel extends Equatable {
  final int pending;
  final double avgDays;
  final int overdue;

  const SlaStatModel({
    required this.pending,
    required this.avgDays,
    required this.overdue,
  });

  factory SlaStatModel.fromJson(Map<String, dynamic> json) {
    return SlaStatModel(
      pending: (json['pending'] as num?)?.toInt() ?? 0,
      avgDays: ((json['avgDays'] ?? json['avg_days']) as num?)?.toDouble() ?? 0.0,
      overdue: (json['overdue'] as num?)?.toInt() ?? 0,
    );
  }

  SlaStat toEntity() => SlaStat(
        pending: pending,
        avgDays: avgDays,
        overdue: overdue,
      );

  @override
  List<Object?> get props => [pending, avgDays, overdue];
}

class ThroughputPointModel extends Equatable {
  final String week;
  final int approved;
  final int rejected;

  const ThroughputPointModel({
    required this.week,
    required this.approved,
    required this.rejected,
  });

  factory ThroughputPointModel.fromJson(Map<String, dynamic> json) {
    return ThroughputPointModel(
      week: (json['week'] ?? json['period'] ?? '') as String,
      approved: (json['approved'] as num?)?.toInt() ?? 0,
      rejected: (json['rejected'] as num?)?.toInt() ?? 0,
    );
  }

  ThroughputPoint toEntity() => ThroughputPoint(
        week: week,
        approved: approved,
        rejected: rejected,
      );

  @override
  List<Object?> get props => [week, approved, rejected];
}

class PipelineStageModel extends Equatable {
  final String stage;
  final int count;

  const PipelineStageModel({
    required this.stage,
    required this.count,
  });

  factory PipelineStageModel.fromJson(Map<String, dynamic> json) {
    return PipelineStageModel(
      stage: (json['stage'] ?? json['name'] ?? '') as String,
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }

  PipelineStage toEntity() => PipelineStage(stage: stage, count: count);

  @override
  List<Object?> get props => [stage, count];
}

/// Modelo del dashboard SLA operativo.
///
/// Mapea la respuesta de GET /admin/analytics/sla-dashboard.
class SlaDashboardModel extends Equatable {
  final SlaStatModel investiture;
  final SlaStatModel evidence;
  final SlaStatModel camporee;
  final List<ThroughputPointModel> throughput;
  final List<PipelineStageModel> pipeline;

  const SlaDashboardModel({
    required this.investiture,
    required this.evidence,
    required this.camporee,
    required this.throughput,
    required this.pipeline,
  });

  factory SlaDashboardModel.fromJson(Map<String, dynamic> json) {
    final investitureJson =
        (json['investiture'] as Map<String, dynamic>?) ?? {};
    final evidenceJson = (json['evidence'] as Map<String, dynamic>?) ?? {};
    final camporeeJson = (json['camporee'] as Map<String, dynamic>?) ?? {};

    final throughputRaw = json['throughput'];
    final throughput = throughputRaw is List
        ? throughputRaw
            .map((e) =>
                ThroughputPointModel.fromJson(e as Map<String, dynamic>))
            .toList()
        : <ThroughputPointModel>[];

    final pipelineRaw = json['pipeline'];
    final pipeline = pipelineRaw is List
        ? pipelineRaw
            .map(
                (e) => PipelineStageModel.fromJson(e as Map<String, dynamic>))
            .toList()
        : <PipelineStageModel>[];

    return SlaDashboardModel(
      investiture: SlaStatModel.fromJson(investitureJson),
      evidence: SlaStatModel.fromJson(evidenceJson),
      camporee: SlaStatModel.fromJson(camporeeJson),
      throughput: throughput,
      pipeline: pipeline,
    );
  }

  SlaDashboard toEntity() => SlaDashboard(
        investiture: investiture.toEntity(),
        evidence: evidence.toEntity(),
        camporee: camporee.toEntity(),
        throughput: throughput.map((e) => e.toEntity()).toList(),
        pipeline: pipeline.map((e) => e.toEntity()).toList(),
      );

  @override
  List<Object?> get props =>
      [investiture, evidence, camporee, throughput, pipeline];
}
