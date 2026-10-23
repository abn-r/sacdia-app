import 'package:equatable/equatable.dart';
import '../../domain/entities/sla_dashboard.dart';

class SlaStatModel extends Equatable {
  final int pending;
  final double avgDays;
  final int overdue;
  final int? overdueThresholdDays;

  const SlaStatModel({
    required this.pending,
    required this.avgDays,
    required this.overdue,
    this.overdueThresholdDays,
  });

  factory SlaStatModel.fromJson(Map<String, dynamic> json) {
    final threshold = (json['overdueThresholdDays'] ??
        json['overdue_threshold_days']) as num?;
    return SlaStatModel(
      pending: (json['pending'] as num?)?.toInt() ?? 0,
      avgDays:
          ((json['avgDays'] ?? json['avg_days']) as num?)?.toDouble() ?? 0.0,
      overdue: (json['overdue'] as num?)?.toInt() ?? 0,
      overdueThresholdDays:
          threshold != null && threshold > 0 ? threshold.toInt() : null,
    );
  }

  SlaStat toEntity() => SlaStat(
        pending: pending,
        avgDays: avgDays,
        overdue: overdue,
        overdueThresholdDays: overdueThresholdDays,
      );

  @override
  List<Object?> get props => [pending, avgDays, overdue, overdueThresholdDays];
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
      week: (json['week'] ?? json['period'] ?? '').toString(),
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
      stage: (json['stage'] ??
              json['label'] ??
              json['name'] ??
              json['status'] ??
              '')
          .toString(),
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

  /// Acepta el contrato actual del backend (`SlaDashboardDto`:
  /// `investiture.total_pending`, `validation.total_pending`,
  /// `camporee.{clubs,members,payments}_pending`, `investiture.pipeline`)
  /// y el formato legado con `{pending, avgDays, overdue}` por proceso.
  factory SlaDashboardModel.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> section(String key) {
      final value = json[key];
      return value is Map<String, dynamic> ? value : const {};
    }

    int count(Map<String, dynamic> source, String key) =>
        (source[key] as num?)?.toInt() ?? 0;

    final investitureJson = section('investiture');
    final validationJson = section('validation');
    final evidenceJson = section('evidence');
    final camporeeJson = section('camporee');
    final timingJson = section('timing');

    final investiture = SlaStatModel(
      pending: (investitureJson['pending'] as num?)?.toInt() ??
          count(investitureJson, 'total_pending'),
      avgDays: ((investitureJson['avgDays'] ??
                  investitureJson['avg_days'] ??
                  timingJson['avg_days_total']) as num?)
              ?.toDouble() ??
          0.0,
      overdue: count(investitureJson, 'overdue'),
    );

    final evidence = evidenceJson.isNotEmpty
        ? SlaStatModel.fromJson(evidenceJson)
        : SlaStatModel(
            pending: count(validationJson, 'total_pending'),
            avgDays: 0.0,
            overdue: 0,
          );

    final camporee = camporeeJson.containsKey('pending')
        ? SlaStatModel.fromJson(camporeeJson)
        : SlaStatModel(
            pending: count(camporeeJson, 'clubs_pending') +
                count(camporeeJson, 'members_pending') +
                count(camporeeJson, 'payments_pending'),
            avgDays: 0.0,
            overdue: 0,
          );

    final throughputRaw = json['throughput'];
    final throughput = throughputRaw is List
        ? throughputRaw
            .whereType<Map<String, dynamic>>()
            .map(ThroughputPointModel.fromJson)
            .toList()
        : <ThroughputPointModel>[];

    final pipelineRaw = json['pipeline'] ?? investitureJson['pipeline'];
    final pipeline = pipelineRaw is List
        ? pipelineRaw
            .whereType<Map<String, dynamic>>()
            .map(PipelineStageModel.fromJson)
            .toList()
        : <PipelineStageModel>[];

    return SlaDashboardModel(
      investiture: investiture,
      evidence: evidence,
      camporee: camporee,
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
