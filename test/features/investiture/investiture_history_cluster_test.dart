import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/investiture/domain/entities/investiture_history_cluster.dart';
import 'package:sacdia_app/features/investiture/domain/entities/investiture_history_entry.dart';

InvestitureHistoryEntry _entry({
  required int id,
  required InvestitureAction action,
  required DateTime at,
  String name = 'Admin',
  String lastName = 'SACDIA',
  String? comments,
}) {
  return InvestitureHistoryEntry(
    id: id,
    action: action,
    performedAt: at,
    performerName: name,
    performerLastName: lastName,
    comments: comments,
  );
}

void main() {
  final stamp = DateTime.utc(2026, 6, 23, 21, 38);

  test('groups consecutive same-actor same-minute approvals', () {
    final history = [
      _entry(
          id: 1,
          action: InvestitureAction.submitted,
          at: stamp.subtract(const Duration(days: 8))),
      _entry(id: 2, action: InvestitureAction.clubApproved, at: stamp),
      _entry(id: 3, action: InvestitureAction.coordinatorApproved, at: stamp),
      _entry(id: 4, action: InvestitureAction.fieldApproved, at: stamp),
    ];

    final clusters = clusterInvestitureHistory(history);

    expect(clusters, hasLength(2));
    expect(clusters[0].entries, hasLength(1));
    expect(clusters[0].representative.action, InvestitureAction.submitted);
    expect(clusters[1].isGrouped, isTrue);
    expect(clusters[1].entries.map((e) => e.action), [
      InvestitureAction.clubApproved,
      InvestitureAction.coordinatorApproved,
      InvestitureAction.fieldApproved,
    ]);
  });

  test('does not group different performers or minutes', () {
    final history = [
      _entry(
        id: 1,
        action: InvestitureAction.clubApproved,
        at: stamp,
        name: 'Abner',
        lastName: 'Reyes',
      ),
      _entry(id: 2, action: InvestitureAction.coordinatorApproved, at: stamp),
      _entry(
        id: 3,
        action: InvestitureAction.fieldApproved,
        at: stamp.add(const Duration(minutes: 1)),
      ),
    ];

    final clusters = clusterInvestitureHistory(history);
    expect(clusters, hasLength(3));
  });

  test('does not group non-approval actions into the chain', () {
    final history = [
      _entry(id: 1, action: InvestitureAction.clubApproved, at: stamp),
      _entry(id: 2, action: InvestitureAction.rejected, at: stamp),
    ];

    expect(clusterInvestitureHistory(history), hasLength(2));
  });

  test('latestInvestitureEntry uses performedAt, not list order', () {
    final older = _entry(
      id: 1,
      action: InvestitureAction.submitted,
      at: stamp.subtract(const Duration(days: 1)),
    );
    final newer = _entry(id: 2, action: InvestitureAction.invested, at: stamp);

    expect(latestInvestitureEntry([newer, older])!.id, 2);
    expect(latestInvestitureEntry([older, newer])!.id, 2);
  });

  test('merges distinct comments inside a group', () {
    final cluster = InvestitureHistoryCluster([
      _entry(
        id: 1,
        action: InvestitureAction.clubApproved,
        at: stamp,
        comments: 'Ok club',
      ),
      _entry(
        id: 2,
        action: InvestitureAction.coordinatorApproved,
        at: stamp,
        comments: 'Ok club',
      ),
      _entry(
        id: 3,
        action: InvestitureAction.fieldApproved,
        at: stamp,
        comments: 'Ok campo',
      ),
    ]);

    expect(cluster.comments, 'Ok club\n\nOk campo');
  });
}
