import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/honors/domain/entities/honor_requirement.dart';
import 'package:sacdia_app/features/honors/domain/entities/requirement_evidence.dart';
import 'package:sacdia_app/features/honors/domain/entities/user_honor.dart';
import 'package:sacdia_app/features/honors/domain/entities/user_honor_requirement_progress.dart';
import 'package:sacdia_app/features/honors/presentation/utils/honor_submission_readiness.dart';

/// These tests encode the rules of
/// `sacdia-backend/src/honors/honor-validation-workflow.service.ts`
/// (`assertInAppSubmitEligibility`, `evaluateRequirementNode`,
/// `evaluateChoiceGroup`, `assertCompletedAt`).
void main() {
  final today = DateTime(2026, 11, 4);
  final goodDate = DateTime(2026, 10, 1);

  HonorRequirement req(
    int id, {
    int? number,
    int? parentId,
    bool choice = false,
    int? choiceMin,
    bool evidence = false,
    List<HonorRequirement> children = const [],
  }) {
    return HonorRequirement(
      id: id,
      honorId: 1,
      requirementNumber: number ?? id,
      text: 'Requisito $id',
      parentId: parentId,
      isChoiceGroup: choice,
      choiceMin: choiceMin,
      requiresEvidence: evidence,
      hasSubItems: children.isNotEmpty,
      children: children,
    );
  }

  UserHonorRequirementProgress done(int id, {int evidences = 0}) {
    return UserHonorRequirementProgress(
      requirementId: id,
      requirementNumber: id,
      text: 'Requisito $id',
      completed: true,
      evidences: [
        for (var i = 0; i < evidences; i++)
          RequirementEvidence(
            id: id * 100 + i,
            evidenceType: EvidenceType.image,
            url: 'https://example.com/$id/$i.jpg',
          ),
      ],
    );
  }

  UserHonorRequirementProgress notDone(int id, {int evidences = 0}) {
    return done(id, evidences: evidences).copyWith(completed: false);
  }

  HonorSubmissionReadiness compute(
    List<HonorRequirement> requirements,
    List<UserHonorRequirementProgress> progress, {
    DateTime? completedAt,
    HonorCompletionMode mode = HonorCompletionMode.inApp,
    bool requireCompletionDate = true,
  }) {
    return computeHonorSubmissionReadiness(
      requirements: requirements,
      progress: progress,
      completedAt: completedAt ?? goodDate,
      mode: mode,
      requireCompletionDate: requireCompletionDate,
      now: today,
    );
  }

  group('leaves', () {
    test('a leaf is todo until its row is ticked, then done', () {
      final reqs = [req(1), req(2)];

      final none = compute(reqs, const []);
      expect(
          none.items.map((i) => i.status),
          everyElement(
            RequirementStatus.todo,
          ));
      expect(none.doneCount, 0);
      expect(none.totalCount, 2);
      expect(none.canSubmit, isFalse);

      final one = compute(reqs, [done(1)]);
      expect(one.items[0].status, RequirementStatus.done);
      expect(one.items[1].status, RequirementStatus.todo);
      expect(one.doneCount, 1);
      expect(one.unsatisfiedCount, 1);
      expect(one.fraction, 0.5);

      final all = compute(reqs, [done(1), done(2)]);
      expect(all.doneCount, 2);
      expect(all.fraction, 1);
      expect(all.canSubmit, isTrue);
    });

    test('an unticked progress row (only a draft answer) does not count', () {
      final r = compute([req(1)], [notDone(1)]);
      expect(r.items.single.status, RequirementStatus.todo);
      expect(r.canSubmit, isFalse);
    });

    test('a honor with no requirements is satisfied (backend L423)', () {
      final r = compute(const [], const []);
      expect(r.totalCount, 0);
      expect(r.allRequirementsSatisfied, isTrue);
      expect(r.canSubmit, isTrue);
      expect(r.fraction, 0);
    });

    test('items follow the requirement number, not the list order', () {
      final r = compute([req(10, number: 2), req(11, number: 1)], const []);
      expect(r.items.map((i) => i.requirement.id), [11, 10]);
    });
  });

  group('parents (non choice)', () {
    final parent = req(1, children: [
      req(2, parentId: 1),
      req(3, parentId: 1),
      req(4, parentId: 1),
    ]);

    test('all children are needed and the parent tick is ignored', () {
      final partial = compute([parent], [done(1), done(2), done(3)]);
      final item = partial.items.single;
      expect(item.status, RequirementStatus.partial);
      expect(item.isSatisfied, isFalse);
      expect(item.childTotal, 3);
      expect(item.childRequired, 3);
      expect(item.childSatisfied, 2);
      expect(partial.fraction, closeTo(2 / 3, 1e-9));
      expect(partial.canSubmit, isFalse);

      // Children done, parent row never ticked: still satisfied.
      final full = compute([parent], [done(2), done(3), done(4)]);
      expect(full.items.single.status, RequirementStatus.done);
      expect(full.canSubmit, isTrue);
    });

    test('a parent with only a ticked own row is not satisfied', () {
      final r = compute([parent], [done(1)]);
      expect(r.items.single.isSatisfied, isFalse);
      expect(r.items.single.ownCompleted, isTrue);
      // Ticked own row still shows work started.
      expect(r.items.single.status, RequirementStatus.partial);
    });

    test('nested parents need every leaf below', () {
      final nested = req(1, children: [
        req(2, parentId: 1, children: [
          req(3, parentId: 2),
          req(4, parentId: 2),
        ]),
        req(5, parentId: 1),
      ]);
      expect(
        compute([nested], [done(3), done(5)]).items.single.isSatisfied,
        isFalse,
      );
      expect(
        compute([nested], [done(3), done(4), done(5)]).items.single.status,
        RequirementStatus.done,
      );
      // A grandchild done is progress even if no direct child is satisfied.
      expect(
        compute([nested], [done(3)]).items.single.status,
        RequirementStatus.partial,
      );
    });
  });

  group('choice groups', () {
    HonorRequirement group({int? min, bool evidence = false}) => req(
          1,
          choice: true,
          choiceMin: min,
          evidence: evidence,
          children: [
            req(2, parentId: 1),
            req(3, parentId: 1),
            req(4, parentId: 1),
          ],
        );

    test('needs choice_min satisfied children', () {
      final g = group(min: 2);
      final one = compute([g], [done(2)]);
      expect(one.items.single.status, RequirementStatus.partial);
      expect(one.items.single.childRequired, 2);
      expect(one.items.single.childSatisfied, 1);
      expect(one.canSubmit, isFalse);

      final two = compute([g], [done(2), done(4)]);
      expect(two.items.single.status, RequirementStatus.done);
      expect(two.canSubmit, isTrue);
    });

    test('a null choice_min means one child (backend L569)', () {
      final g = group();
      expect(compute([g], const []).items.single.childRequired, 1);
      expect(compute([g], [done(3)]).canSubmit, isTrue);
    });

    test('choice_min 0 is satisfied without any child', () {
      final r = compute([group(min: 0)], const []);
      expect(r.items.single.isSatisfied, isTrue);
      expect(r.items.single.status, RequirementStatus.done);
      expect(r.canSubmit, isTrue);
    });

    test(
        'a choice group can reach 100% (children beyond the minimum are optional)',
        () {
      final r = compute([group(min: 1)], [done(2)]);
      expect(r.fraction, 1);
    });

    test('doing more than the minimum is fine', () {
      final r = compute([group(min: 1)], [done(2), done(3), done(4)]);
      expect(r.items.single.status, RequirementStatus.done);
    });

    test('the group tick is not required, only its children', () {
      final r = compute([group(min: 1)], [done(1), done(2)]);
      expect(r.items.single.isSatisfied, isTrue);
    });
  });

  group('required evidence', () {
    test('a ticked leaf that requires evidence is satisfied but not ready', () {
      final r = compute([req(1, evidence: true)], [done(1)]);
      final item = r.items.single;
      expect(item.isSatisfied, isTrue);
      expect(item.status, RequirementStatus.partial);
      expect(item.missingEvidenceIds, [1]);
      expect(item.fraction, 0.5);
      expect(r.satisfiedCount, 1);
      expect(r.doneCount, 0);
      expect(r.unsatisfiedCount, 0);
      expect(r.missingEvidenceCount, 1);
      expect(r.canSubmit, isFalse);
    });

    test('evidence on a ticked leaf makes it done', () {
      final r = compute([req(1, evidence: true)], [done(1, evidences: 1)]);
      expect(r.items.single.status, RequirementStatus.done);
      expect(r.missingEvidenceCount, 0);
      expect(r.canSubmit, isTrue);
    });

    test('evidence on an unticked row does not count (backend L441-L458)', () {
      final r = compute(
        [req(1, evidence: true)],
        [notDone(1, evidences: 2)],
      );
      expect(r.items.single.status, RequirementStatus.todo);
      expect(r.items.single.ownEvidenceCount, 2);
      expect(r.canSubmit, isFalse);
    });

    test('an unsatisfied requirement does not ask for evidence yet', () {
      final r = compute([req(1, evidence: true)], const []);
      expect(r.missingEvidenceCount, 0);
      expect(r.unsatisfiedCount, 1);
    });

    test('a satisfied parent that requires evidence needs its own row', () {
      final parent = req(1, evidence: true, children: [
        req(2, parentId: 1),
      ]);
      final noOwn = compute([parent], [done(2)]);
      expect(noOwn.items.single.isSatisfied, isTrue);
      expect(noOwn.missingEvidenceIds, [1]);

      // Evidence on a parent row that was never ticked is ignored.
      final unticked = compute([parent], [done(2), notDone(1, evidences: 1)]);
      expect(unticked.missingEvidenceIds, [1]);

      final ok = compute([parent], [done(2), done(1, evidences: 1)]);
      expect(ok.items.single.status, RequirementStatus.done);
      expect(ok.canSubmit, isTrue);
    });

    test('only the first choice_min satisfied children ask for evidence', () {
      final g = req(1, choice: true, choiceMin: 1, children: [
        req(2, parentId: 1, number: 1, evidence: true),
        req(3, parentId: 1, number: 2, evidence: true),
      ]);
      // Child 2 (first by number) is selected: it needs evidence, child 3 does
      // not even though it is ticked without evidence.
      final needs = compute([g], [done(2), done(3, evidences: 1)]);
      expect(needs.missingEvidenceIds, [2]);

      final ok = compute([g], [done(2, evidences: 1), done(3)]);
      expect(ok.missingEvidenceIds, isEmpty);
      expect(ok.canSubmit, isTrue);

      // Only the later child ticked: that one is the selected path.
      final later = compute([g], [done(3)]);
      expect(later.missingEvidenceIds, [3]);
    });

    test('a choice group that requires evidence asks for its own row', () {
      final g = req(1, choice: true, choiceMin: 1, evidence: true, children: [
        req(2, parentId: 1),
      ]);
      expect(compute([g], [done(2)]).missingEvidenceIds, [1]);
      expect(
        compute([g], [done(2), done(1, evidences: 1)]).missingEvidenceIds,
        isEmpty,
      );
      // choice_min 0: still asks for the group's own evidence (backend L574).
      // (A group with no sub-items at all is a plain leaf instead.)
      final zero = req(1,
          choice: true,
          choiceMin: 0,
          evidence: true,
          children: [req(2, parentId: 1)]);
      expect(compute([zero], const []).missingEvidenceIds, [1]);
    });

    test('missing evidence ids are unique and sorted across the honor', () {
      final r = compute(
        [req(5, evidence: true), req(2, evidence: true)],
        [done(5), done(2)],
      );
      expect(r.missingEvidenceIds, [2, 5]);
    });
  });

  group('completion date and mode', () {
    test('the date is required by default (strictest reading)', () {
      final r = computeHonorSubmissionReadiness(
        requirements: [req(1)],
        progress: [done(1)],
        completedAt: null,
        mode: HonorCompletionMode.inApp,
        now: today,
      );
      expect(r.allRequirementsSatisfied, isTrue);
      expect(r.hasCompletionDate, isFalse);
      expect(r.canSubmit, isFalse);
    });

    test('the backend flag is off today, so the date can be made optional', () {
      final r = computeHonorSubmissionReadiness(
        requirements: [req(1)],
        progress: [done(1)],
        completedAt: null,
        mode: HonorCompletionMode.inApp,
        requireCompletionDate: false,
        now: today,
      );
      expect(r.canSubmit, isTrue);
    });

    test('a date outside 1960..today is rejected even when optional', () {
      for (final bad in [DateTime(1959, 12, 31), DateTime(2026, 11, 5)]) {
        final r = compute([req(1)], [done(1)],
            completedAt: bad, requireCompletionDate: false);
        expect(r.canSubmit, isFalse, reason: '$bad');
      }
      expect(
        compute([req(1)], [done(1)], completedAt: DateTime(2026, 11, 4))
            .canSubmit,
        isTrue,
      );
    });

    test('only IN_APP honors can be sent from the checklist', () {
      for (final mode in [
        HonorCompletionMode.external,
        HonorCompletionMode.undecided,
      ]) {
        final r = compute([req(1)], [done(1)], mode: mode);
        expect(r.isInApp, isFalse);
        expect(r.canSubmit, isFalse);
      }
    });
  });

  group('external honors', () {
    // Rules of `assertExternalSubmitEligibility`
    // (honor-validation-workflow.service.ts L361-L379): format (L367) and a
    // general evidence (L373); the date follows `assertCompletedAt` L320-L331.
    UserHonor row({
      HonorCompletionMode mode = HonorCompletionMode.external,
      String? document,
      List<String> images = const [],
      DateTime? completedAt,
    }) {
      return UserHonor(
        id: 77,
        honorId: 7,
        userId: 'user-1',
        completionMode: mode,
        document: document,
        images: images,
        completedAt: completedAt,
        date: DateTime(2026, 6, 11),
      );
    }

    ExternalSubmissionReadiness ready(UserHonor honor,
            {bool requireCompletionDate = true}) =>
        computeExternalSubmissionReadiness(
          userHonor: honor,
          requireCompletionDate: requireCompletionDate,
          now: today,
        );

    test('nothing done: 0 of 3 and it cannot go (L367)', () {
      final r = ready(row());
      expect(r.doneCount, 0);
      expect(r.fraction, 0);
      expect(r.canSubmit, isFalse);
    });

    test('format, one evidence and the date: 3 of 3 and it can go', () {
      final r = ready(row(
        document: 'https://example.com/f.pdf',
        images: const ['https://example.com/1.jpg'],
        completedAt: goodDate,
      ));
      expect(r.hasFormat, isTrue);
      expect(r.hasGeneralEvidence, isTrue);
      expect(r.hasCompletionDate, isTrue);
      expect(r.fraction, 1);
      expect(r.canSubmit, isTrue);
    });

    test('the format alone is not enough: an evidence is required (L373)', () {
      final r = ready(row(
        document: 'https://example.com/f.pdf',
        completedAt: goodDate,
      ));
      expect(r.hasFormat, isTrue);
      expect(r.hasGeneralEvidence, isFalse);
      expect(r.canSubmit, isFalse);
      expect(r.fraction, closeTo(2 / 3, 1e-9));
    });

    test('evidence alone is not enough: the format is required (L367)', () {
      final r = ready(row(
        images: const ['https://example.com/1.jpg'],
        completedAt: goodDate,
      ));
      expect(r.hasFormat, isFalse);
      expect(r.hasGeneralEvidence, isTrue);
      expect(r.canSubmit, isFalse);
    });

    test('an empty document string is no format (L381-L385)', () {
      final r = ready(row(
        document: '',
        images: const ['https://example.com/1.jpg'],
        completedAt: goodDate,
      ));
      expect(r.hasFormat, isFalse);
      expect(r.canSubmit, isFalse);
    });

    test('the date is required by the app but not by the backend flag (L27)',
        () {
      final honor = row(
        document: 'https://example.com/f.pdf',
        images: const ['https://example.com/1.jpg'],
      );
      expect(ready(honor).canSubmit, isFalse);
      expect(ready(honor, requireCompletionDate: false).canSubmit, isTrue);
    });

    test('a date outside 1960..today never passes (L327)', () {
      for (final bad in [DateTime(1959, 12, 31), DateTime(2026, 11, 5)]) {
        final r = ready(
          row(
            document: 'https://example.com/f.pdf',
            images: const ['https://example.com/1.jpg'],
            completedAt: bad,
          ),
          requireCompletionDate: false,
        );
        expect(r.canSubmit, isFalse, reason: '$bad');
      }
    });

    test('only EXTERNAL honors can be sent from this path (L287-L292)', () {
      for (final mode in [
        HonorCompletionMode.inApp,
        HonorCompletionMode.undecided,
      ]) {
        final r = ready(row(
          mode: mode,
          document: 'https://example.com/f.pdf',
          images: const ['https://example.com/1.jpg'],
          completedAt: goodDate,
        ));
        expect(r.isExternal, isFalse);
        expect(r.canSubmit, isFalse);
      }
    });
  });

  group('evidenceParentUpdates', () {
    test('ticks an evidence parent once its children satisfy it', () {
      final parent = req(5, evidence: true, children: [
        req(51, parentId: 5),
        req(52, parentId: 5),
      ]);
      final updates = evidenceParentUpdates(
        roots: [parent],
        progress: [done(51), done(52)],
      );
      expect(updates.single['requirementId'], 5);
      expect(updates.single['completed'], isTrue);
    });

    test('unticks it when a child stops satisfying it', () {
      final parent = req(5, evidence: true, children: [
        req(51, parentId: 5),
        req(52, parentId: 5),
      ]);
      final updates = evidenceParentUpdates(
        roots: [parent],
        progress: [done(5, evidences: 1), done(51)],
      );
      expect(updates.single['completed'], isFalse);
    });

    test('a choice group needs only choice_min children', () {
      final group = req(6,
          choice: true,
          choiceMin: 1,
          evidence: true,
          children: [req(61, parentId: 6), req(62, parentId: 6)]);
      final updates = evidenceParentUpdates(
        roots: [group],
        progress: [done(62)],
      );
      expect(updates.single['completed'], isTrue);
    });

    test('leaves parents without evidence and parents in step alone', () {
      final plain = req(7, children: [req(71, parentId: 7)]);
      final inStep = req(8, evidence: true, children: [req(81, parentId: 8)]);
      expect(
        evidenceParentUpdates(
          roots: [plain, inStep],
          progress: [done(71), done(81), done(8)],
        ),
        isEmpty,
      );
    });
  });

  group('a "choose N" group with no sub-items (catalog mistake)', () {
    HonorSubmissionReadiness run(List<UserHonorRequirementProgress> progress) =>
        computeHonorSubmissionReadiness(
          requirements: [req(102, choice: true, choiceMin: 3)],
          progress: progress,
          completedAt: goodDate,
          mode: HonorCompletionMode.inApp,
          now: today,
        );

    test('is a plain requirement: done once its own row is completed', () {
      final r = run([done(102)]);
      expect(r.items.single.isSatisfied, isTrue);
      expect(r.items.single.status, RequirementStatus.done);
      expect(r.items.single.isLeaf, isTrue);
      expect(r.canSubmit, isTrue);
    });

    test('is pending without a completed row', () {
      final r = run(const []);
      expect(r.items.single.isSatisfied, isFalse);
      expect(r.canSubmit, isFalse);
    });
  });
}
