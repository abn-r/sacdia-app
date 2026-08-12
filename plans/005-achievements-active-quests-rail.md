# 005 — Surface in-progress achievements as active quest cards

- **Status**: CANCELLED — removed after review (not functional for product)
- **Commit**: `11ee503`
- **Severity**: HIGH
- **Category**: Missed opportunities / Purpose & frequency
- **Estimated scope**: 3–4 production files + 1–2 tests; ~250–350 lines

## Problem

Achievements screen leads with summary + filter + flat grid. In-progress items
are buryable under filter chips. Reference video (`ssstwitter…mp4`) leads with
**active quest cards** (badge, title, progress fraction, points pill) before the
achievements grid.

Current insertion point — summary then filters, no quest surface:

```dart
// lib/features/achievements/presentation/views/achievements_view.dart:95-109 — current
SliverToBoxAdapter(
  child: _SummaryHeader(
    completed: response.summary.totalCompleted,
    total: all.length,
    points: response.summary.totalPoints,
    percentage: response.summary.completionPercentage,
  ),
),
SliverToBoxAdapter(
  child: _FilterBar(
    filter: _filter,
    counts: counts,
    onChanged: (value) => setState(() => _filter = value),
  ),
),
```

In-progress is already a first-class visual state
(`AchievementVisualState.inProgress` via `UserAchievement.isInProgress`).

## Target

Insert an **Active quests** section between `_SummaryHeader` and `_FilterBar`:

1. Pure mapper (presentation layer) selects only
   `visualState == AchievementVisualState.inProgress`.
2. Vertical list of compact cards (not a second API call — reuse
   `UserAchievementsResponse` already loaded).
3. If zero active quests → section omitted; grid unchanged.
4. Filter chips still filter **only the grid**; quest rail always shows all
   current in-progress items (independent of `_filter`).
5. Cap visible quests at **6** (sorted by highest
   `progressPercentage` desc, then name). Remainder stay reachable via grid +
   inProgress filter.
6. Tap opens existing `_showDetailSheet` with the same
   `AchievementWithProgress`.
7. Press feedback: `AnimatedScale` to `0.97`, `SacMotion.press` (140ms),
   `SacMotion.easeOut` / `Curves.easeOut` matching grid cards; reduced motion →
   no scale change.
8. Card content (existing fields only — no silhouette collectibles):
   - `AchievementBadge` (existing widget)
   - Title (`achievement.name`; secrets in-progress that are masked: show `???`
     only if `achievement.secret && !(userAchievement?.isCompleted ?? false)` —
     same rule as detail sheet)
   - Fraction `progressValue / progressTarget` (safe if `progressTarget <= 0`)
   - `AchievementProgressBar`
   - Remaining: `max(progressTarget - progressValue, 0)`
   - Points pill: `{points} pts` using `achievement.points`

Exact motion values:

| Token / value | Source |
|---|---|
| press scale | `0.97` |
| press duration | `SacMotion.press` = 140ms |
| press curve | `SacMotion.easeOut` = `Cubic(0.23, 1, 0.32, 1)` (or `Curves.easeOut` if matching `achievement_grid_card.dart`) |
| card enter (optional stagger) | delay `index * SacMotion.stagger` (40ms), max index 5; opacity + `translateY(8)` → 0; duration `SacMotion.standard` (200ms); curve `SacMotion.easeOut`; skip if reduced motion |
| max quests shown | `6` |

## Repo conventions to follow

- Motion: `lib/core/animations/motion_tokens.dart`.
- Press exemplar: `lib/features/achievements/presentation/widgets/achievement_grid_card.dart:154-161`
  (`onTapDown` / `AnimatedScale` / reduce-motion gate).
- Detail open: `achievements_view.dart:236-249` (`showModalBottomSheet` +
  `AchievementDetailSheet`).
- Do **not** parse `Achievement.criteria` for quest identity or navigation.
- Do **not** add packages, endpoints, or formation/honors collection.

## Steps

1. Create `lib/features/achievements/presentation/utils/active_quest_mapper.dart`
   with a pure function, e.g.:

```dart
List<AchievementWithProgress> selectActiveQuests(
  List<AchievementWithProgress> items, {
  int limit = 6,
}) {
  final active = items.where((item) {
    final state =
        item.userAchievement?.visualState ?? AchievementVisualState.locked;
    return state == AchievementVisualState.inProgress;
  }).toList();
  active.sort((a, b) {
    final pa = a.userAchievement?.progressPercentage ?? 0;
    final pb = b.userAchievement?.progressPercentage ?? 0;
    final byProgress = pb.compareTo(pa);
    if (byProgress != 0) return byProgress;
    return a.achievement.name.compareTo(b.achievement.name);
  });
  if (active.length <= limit) return active;
  return active.take(limit).toList();
}

int remainingFor(UserAchievement ua) {
  final target = ua.progressTarget;
  if (target <= 0) return 0;
  final rem = target - ua.progressValue;
  return rem < 0 ? 0 : rem;
}
```

2. RED tests in
   `test/features/achievements/presentation/utils/active_quest_mapper_test.dart`:
   - only inProgress mapped
   - unlocked/locked excluded
   - remaining clamps at 0; `progressTarget <= 0` → remaining 0
   - limit 6 enforced
3. GREEN: implement mapper.
4. Create
   `lib/features/achievements/presentation/widgets/active_quest_card.dart`
   and
   `lib/features/achievements/presentation/widgets/active_quests_section.dart`.
   Section takes `List<AchievementWithProgress>` + `ValueChanged`/`onTap`
   callback — no repository calls inside widgets.
5. Wire into `achievements_view.dart` after `_SummaryHeader`, before
   `_FilterBar`. Compute:

```dart
final activeQuests = selectActiveQuests(all);
```

   If `activeQuests.isNotEmpty`, add `SliverToBoxAdapter(child: ActiveQuestsSection(...))`.
6. i18n under `achievements.views` in **all four** locales
   (`en`, `es`, `fr`, `pt-BR`):
   - `active_quests_title` (e.g. ES: `"Retos activos"`, EN: `"Active quests"`)
   - `active_quest_remaining` with `{count}` (e.g. ES: `"Faltan {count}"`)
   - Stage **only** the new keys; leave unrelated dirty translation diffs out of
     the commit if the worktree already has rankings/profile edits.
7. Widget test (ProviderScope overrides) covering: rail visible with inProgress;
   rail hidden when none; tap invokes sheet path (or calls `onTap` with correct
   id); Semantics button + min height ≥ 48.

## Boundaries

- Do NOT replace or remove the existing grid / `_FilterBar` / pull-to-refresh.
- Do NOT add silhouette collectible rows or honor/class formation sections.
- Do NOT invent achievement→honor links from `criteria`.
- Do NOT stage unrelated rankings/profile files.
- Do NOT add dependencies.
- If `achievements_view.dart` structure drifted from commit `11ee503`, STOP and
  report.

## Verification

- **Mechanical**:
  ```bash
  cd sacdia-app
  flutter test test/features/achievements/presentation/utils/active_quest_mapper_test.dart
  flutter test test/features/achievements
  ```
  Expected: PASS. No `flutter build`.
- **Feel check**:
  - Open Logros with ≥1 in-progress → quest cards appear above filters.
  - Press a card → scale to ~0.97 then sheet opens.
  - Switch filter to Locked → rail still shows active quests; grid changes.
  - Reduced motion → no press scale / no stagger slide.
  - Slow-mo: stagger ≤ 40ms between cards; no layout thrash.
- **Done when**: mapper tests green; rail present only when active quests exist;
  grid+filters unchanged; no new REST calls.
