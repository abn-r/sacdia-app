import 'package:equatable/equatable.dart';

/// Progreso de una pista (Básico/Avanzado/Extra).
class TrackProgress extends Equatable {
  final int percentage;
  final int? completed;
  final int? total;

  const TrackProgress({
    required this.percentage,
    this.completed,
    this.total,
  });

  factory TrackProgress.fromJson(dynamic value) {
    if (value == null) {
      return const TrackProgress(percentage: 0);
    }

    if (value is num) {
      return TrackProgress(
        percentage: _toPercent(value),
      );
    }

    if (value is String) {
      final parsed = double.tryParse(value);
      if (parsed != null) {
        return TrackProgress(percentage: _toPercent(parsed));
      }
      return const TrackProgress(percentage: 0);
    }

    if (value is Map) {
      return TrackProgress(
        percentage: _toPercent(
            value['percentage'] ?? value['progress'] ?? value['pct']),
        completed: _toInt(value['completed']),
        total: _toInt(value['total']),
      );
    }

    return const TrackProgress(percentage: 0);
  }

  static int _toPercent(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.clamp(0, 100).round();
    if (value is String) {
      final parsed = double.tryParse(value);
      if (parsed != null) return parsed.clamp(0, 100).round();
    }
    return 0;
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  Map<String, dynamic> toJson() => {
        'percentage': percentage,
        if (completed != null) 'completed': completed,
        if (total != null) 'total': total,
      };

  /// Ratio entre 0 y 1.
  double get ratio => percentage.clamp(0, 100) / 100.0;

  bool get isCompleted => percentage >= 100;

  @override
  List<Object?> get props => [percentage, completed, total];
}
