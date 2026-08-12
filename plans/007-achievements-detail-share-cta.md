# 007 — Add Share CTA to unlocked achievement detail sheet

- **Status**: DEFERRED — UI hidden until product contemplates share
- **Commit**: `11ee503`
- **Severity**: HIGH
- **Category**: Missed opportunities / Feedback
- **Estimated scope**: 2 production files + tests + i18n; ~100–160 lines

## Problem

Reference video ends the achievement sheet with a full-width **Share your
progress** button. SACDIA’s detail sheet scrolls content but has no share
action. `share_plus` is already a dependency; achievements never import it.

Sheet ends after prerequisite / type-specific content with no footer CTA
(`achievement_detail_sheet.dart` column ~149–290).

## Target

1. Pure text formatter (no `BuildContext`, no `tr()` inside):

```dart
// lib/features/achievements/presentation/utils/achievement_share_text.dart
String buildAchievementShareText({
  required String template, // already localized, with placeholders
  required String name,
  required String tier,
  required int points,
  String? completedOn, // preformatted or null
}) { /* substitute; never emit the string "null" */ }
```

2. CTA visible **only when**:
   - `userAchievement?.isCompleted == true` **and**
   - `!(achievement.secret && !isCompleted)` — i.e. not secret-masked
   - Practical rule: `isCompleted && !isSecret` where
     `isSecret = achievement.secret && !isCompleted` (same as sheet today).
3. Full-width button, min height **48**, `Semantics(button: true, label: …)`.
4. Press scale `0.97` / `SacMotion.press` / ease-out; reduced motion → no scale.
5. On tap:

```dart
await Share.share(shareText);
```

   Text only — **no** screenshot, XFile, or temp image (MVP).
6. Place CTA at bottom of the scroll column (after existing sections), with
   top spacing ≥ 20 and bottom padding already accounting for safe area.

Exact values:

| Token / value | Source |
|---|---|
| min height | `48` |
| press scale | `0.97` |
| press duration | `SacMotion.press` = 140ms |
| share API | `Share.share` from `package:share_plus/share_plus.dart` |

## Repo conventions to follow

- Dependency already in `pubspec.yaml` (`share_plus`).
- Import pattern: `import 'package:share_plus/share_plus.dart';`
- Prefer text share (unlike virtual_card’s `Share.shareXFiles` for images).
- Button visual: primary/dark filled style consistent with app CTAs; use
  `context.sac` / `AppColors` — do not hardcode Seek’s black unless it matches
  existing primary button patterns in the app.
- i18n keys under `achievements.views` in all 4 locales.

Suggested keys:

- `detail_share`: button label (ES: `"Compartir progreso"`, EN: `"Share your progress"`)
- `detail_share_template`: e.g.
  EN: `"I unlocked {name} ({tier}) — {points} pts on SACDIA"`
  ES: `"Desbloqueé {name} ({tier}) — {points} pts en SACDIA"`

Formatter receives the already-`.tr()`’d template string from the widget.

## Steps

1. RED:
   `test/features/achievements/presentation/utils/achievement_share_text_test.dart`
   - completed text includes name, tier, points
   - null date does not produce `"null"`
   - empty name not used for secret path (caller responsibility — test documents it)
2. Implement `achievement_share_text.dart`.
3. RED widget tests on detail sheet:
   - Share visible when unlocked non-secret
   - Share **absent** when locked / in-progress / secret-masked
   - Semantics + height ≥ 48
4. Wire CTA into `achievement_detail_sheet.dart` (after plan **006** so layout
   already has NEXT block; if 006 not merged, still place CTA at column end).
5. i18n four locales — only new keys.
6. GREEN tests.

## Boundaries

- Do NOT generate images or PDFs for share.
- Do NOT share secret achievement names/descriptions.
- Do NOT write share state into Riverpod.
- Do NOT expand `criteria` parsing.
- Do NOT add packages.
- Coordinate with **006** on the same file — land 006 first or rebase carefully.

## Verification

- **Mechanical**:
  ```bash
  cd sacdia-app
  flutter test test/features/achievements/presentation/utils/achievement_share_text_test.dart
  flutter test test/features/achievements/presentation/views/achievement_detail_sheet_test.dart
  flutter test test/features/achievements
  ```
- **Feel check**:
  - Unlocked achievement → Share visible; tap opens system share sheet with text.
  - In-progress → no Share.
  - Secret incomplete → no Share / no leaked name in any share path.
  - Press → 0.97 scale; reduced motion → no scale.
- **Done when**: share only for unlocked non-secret; tests green; text-only share.
