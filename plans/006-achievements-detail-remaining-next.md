# 006 — Enrich achievement detail with remaining copy and NEXT goal

- **Status**: DONE
- **Commit**: `11ee503`
- **Severity**: HIGH
- **Category**: Missed opportunities / State indication
- **Estimated scope**: 1–2 production files + tests; ~120–200 lines

## Problem

Detail sheet shows a generic progress label + fraction, but not the reference
video’s **status line** (“N more to go”) or **NEXT** goal block (target +
points + progress). Current progress block:

```dart
// lib/features/achievements/presentation/views/achievement_detail_sheet.dart:563-592 — current
return Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Row(
      children: [
        Text(
          'achievements.views.detail_progress'.tr(),
          // ...
        ),
        const Spacer(),
        Text(
          '${userAchievement.progressValue}/${userAchievement.progressTarget}',
          // ...
        ),
      ],
    ),
    const SizedBox(height: 10),
    AchievementProgressBar(
      progress: userAchievement.progressPercentage,
      tier: achievement.tier,
      height: 7,
    ),
  ],
);
```

Shown only when `!isSecret && userAchievement != null && !isCompleted`
(sheet ~267–276).

## Target

For **in-progress, non-secret** achievements:

1. Subtitle under the title (or above progress card), purple/primary-tinted:
   localized **“Faltan {count}”** / **“{count} more to go”** where
   `count = max(progressTarget - progressValue, 0)`. If `progressTarget <= 0`,
   hide remaining subtitle (do not show “Faltan 0” from bad data — prefer hide).
2. Inside `_ProgressSection` (or replace it with a richer card):
   - Small caps / label `NEXT` (`achievements.views.detail_next`)
   - Goal line: keep achievement name or “{progressTarget}” framing — use
     **localized** `detail_next_goal` with `{current}` `{target}` e.g.
     ES: `"{current} de {target}"` — do **not** invent milestone ladders
     (1/5/15/40) without real data.
   - Points pill on the right: `{points} pts` (existing `achievement.points`)
   - `AchievementProgressBar` (already animates 0→value with
     `SacMotion.standard` + `SacMotion.easeOut` — keep it)
3. Safe math in a pure helper (same remaining helper as plan 005 if already
   merged; otherwise duplicate minimal `remainingFor` in
   `presentation/utils/` and share later — prefer one util file
   `achievement_progress_copy.dart` if 005 not landed yet).

Exact motion (progress bar already correct — do not change durations):

| Token | Value |
|---|---|
| bar duration | `SacMotion.standard` = 200ms |
| bar curve | `SacMotion.easeOut` = `Cubic(0.23, 1, 0.32, 1)` |
| reduced motion | bar jumps to final fill (`AchievementProgressBar` existing behavior) |

No new milestone track UI in this plan.

## Repo conventions to follow

- Sheet structure / `_InsetCard` / `_ProgressSection` in
  `achievement_detail_sheet.dart`.
- Progress bar: `achievement_progress_bar.dart` (already SacMotion-correct).
- i18n under `achievements.views.*` — add keys to en/es/fr/pt-BR together.
- Exemplar for points chip styling: existing `_MetaChip` with
  `HugeIcons.strokeRoundedFlash` at sheet ~195–201.

## Steps

1. RED unit tests for remaining / progress copy helpers:
   `test/features/achievements/presentation/utils/achievement_progress_copy_test.dart`
   - remaining clamps; target ≤ 0 → 0
   - progress ratio clamped 0–1
2. Implement helper(s) in
   `lib/features/achievements/presentation/utils/achievement_progress_copy.dart`.
3. RED widget expectations in
   `test/features/achievements/presentation/views/achievement_detail_sheet_test.dart`
   (create if missing): in-progress sheet shows remaining text + NEXT label +
   fraction; `progressTarget <= 0` does not throw; secret in-progress does **not**
   show remaining/NEXT content beyond existing secret hint.
4. Update `_ProgressSection` UI + optional remaining subtitle under title when
   `visualState == inProgress && !isSecret`.
5. Add i18n keys (all 4 locales), e.g.:
   - `detail_remaining`: `"Faltan {count}"` / `"{count} more to go"`
   - `detail_next`: `"SIGUIENTE"` / `"NEXT"`
   - `detail_next_goal`: `"{current} de {target}"` / `"{current} of {target}"`
6. GREEN tests.

## Boundaries

- Do NOT add milestone circles (1/5/15/40) — no typed ladder in API.
- Do NOT parse `criteria` for “next item” names.
- Do NOT add Share in this plan (that is **007**).
- Do NOT add badge reveal (that is **008**).
- Do NOT stage unrelated translation/ranking edits beyond new keys.
- No new packages.

## Verification

- **Mechanical**:
  ```bash
  cd sacdia-app
  flutter test test/features/achievements/presentation/utils/achievement_progress_copy_test.dart
  flutter test test/features/achievements/presentation/views/achievement_detail_sheet_test.dart
  flutter test test/features/achievements
  ```
- **Feel check**:
  - Open in-progress achievement → see remaining copy + NEXT card + bar fill.
  - Slow-mo bar: fills with ease-out from 0, ~200ms.
  - Reduced motion: bar at final value immediately.
  - Secret locked/in-progress: no spoilers (name still `???`, no NEXT from hidden progress details beyond existing rules).
- **Done when**: remaining + NEXT visible for non-secret in-progress; tests green;
  no invented milestones.
