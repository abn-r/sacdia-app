import 'investiture_history_entry.dart';

/// Consecutive approval steps that can share one timeline row.
///
/// Grouping rule: same performer, same local minute, approval-family actions.
class InvestitureHistoryCluster {
  InvestitureHistoryCluster(List<InvestitureHistoryEntry> entries)
      : entries = List<InvestitureHistoryEntry>.unmodifiable(entries) {
    if (entries.isEmpty) {
      throw ArgumentError('InvestitureHistoryCluster requires entries');
    }
  }

  final List<InvestitureHistoryEntry> entries;

  InvestitureHistoryEntry get representative => entries.last;

  bool get isGrouped => entries.length > 1;

  String? get comments {
    final parts = <String>[];
    for (final entry in entries) {
      final text = entry.comments?.trim();
      if (text != null && text.isNotEmpty && !parts.contains(text)) {
        parts.add(text);
      }
    }
    if (parts.isEmpty) return null;
    return parts.join('\n\n');
  }
}

InvestitureHistoryEntry? latestInvestitureEntry(
  List<InvestitureHistoryEntry> history,
) {
  if (history.isEmpty) return null;
  return history.reduce(
    (a, b) => a.performedAt.isAfter(b.performedAt) ? a : b,
  );
}

bool shouldGroupInvestitureEntries(
  InvestitureHistoryEntry previous,
  InvestitureHistoryEntry next,
) {
  if (!previous.action.isApprovalStep || !next.action.isApprovalStep) {
    return false;
  }
  if (previous.performerFullName != next.performerFullName) return false;
  return _sameLocalMinute(previous.performedAt, next.performedAt);
}

/// Chronological clusters. Approval chains in the same minute collapse to one.
List<InvestitureHistoryCluster> clusterInvestitureHistory(
  List<InvestitureHistoryEntry> history,
) {
  if (history.isEmpty) return const [];

  final sorted = [...history]..sort((a, b) {
      final byTime = a.performedAt.compareTo(b.performedAt);
      if (byTime != 0) return byTime;
      return a.id.compareTo(b.id);
    });

  final clusters = <InvestitureHistoryCluster>[];
  var bucket = <InvestitureHistoryEntry>[sorted.first];

  for (var i = 1; i < sorted.length; i++) {
    final next = sorted[i];
    if (shouldGroupInvestitureEntries(bucket.last, next)) {
      bucket.add(next);
    } else {
      clusters.add(InvestitureHistoryCluster(bucket));
      bucket = [next];
    }
  }
  clusters.add(InvestitureHistoryCluster(bucket));
  return clusters;
}

bool _sameLocalMinute(DateTime a, DateTime b) {
  final localA = a.toLocal();
  final localB = b.toLocal();
  return localA.year == localB.year &&
      localA.month == localB.month &&
      localA.day == localB.day &&
      localA.hour == localB.hour &&
      localA.minute == localB.minute;
}
