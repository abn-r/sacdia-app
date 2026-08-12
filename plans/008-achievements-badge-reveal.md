# 008 — One-shot accessible badge reveal in achievement detail

- **Status**: DONE
- **Commit**: `11ee503`
- **Severity**: MEDIUM
- **Category**: Physicality & origin / Missed opportunities
- **Estimated scope**: 2–3 production files + tests; ~120–180 lines

## Problem

Detail `_BadgeHero` shows a static radial glow + large `AchievementBadge`.
Reference video gives the badge **presence** on sheet open (glow/rays + reveal).
Grid already has shimmer/pulse loops on high tiers — those must **not** gain a
3D spin (frequency too high).

Current hero (static):

```dart
// lib/features/achievements/presentation/views/achievement_detail_sheet.dart:362-394 — current
return SizedBox(
  width: 255,
  height: 255,
  child: Stack(
    alignment: Alignment.center,
    children: [
      Container(
        width: 240,
        height: 240,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [glowCore, glowMid, glowMid.withValues(alpha: 0)],
            stops: const [0.0, 0.55, 1.0],
          ),
        ),
      ),
      AchievementBadge(
        badgeImageUrl: achievement.badgeImageUrl,
        tier: tier,
        visualState: visualState,
        isSecret: isSecret,
        size: 203,
        progress: progress,
      ),
    ],
  ),
);
```

Sheet content already enters with `SacMotion.modal` + `enterScale` 0.96
(`achievement_detail_sheet.dart` ~29–46). Badge needs its **own** one-shot
reveal so the hero feels special without fighting the sheet fade.

## Target

1. Add duration token:

```dart
// lib/core/animations/motion_tokens.dart
static const Duration badgeReveal = Duration(milliseconds: 480);
```

   480ms is allowed: rare / first-open delight (AUDIT: marketing/explanatory may
   exceed the 300ms UI cap). Do **not** use 480ms for press/filter chips.

2. Create
   `lib/features/achievements/presentation/widgets/achievement_badge_reveal.dart`:
   - StatefulWidget, local `AnimationController` (vsync), disposed in `dispose`
   - On first frame: if reduced motion → `controller.value = 1`; else
     `forward()` once (never `repeat`)
   - Animate **only** `opacity` + `Transform` (perspective + `rotateY`)
   - Start: opacity 0, angle ≈ `0.55` turns toward identity… practical recipe:

```dart
// target builder — GPU-friendly
final t = animation.value; // 0 → 1, curve SacMotion.easeOut
final angle = (1 - t) * 0.85; // radians; settles at 0
return RepaintBoundary(
  child: Opacity(
    opacity: t,
    child: Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.001)
        ..rotateY(angle),
      child: child,
    ),
  ),
);
```

   - Prefer starting scale from `SacMotion.enterScale` (0.96) **or** the Y-rotate
     above — pick **one** primary motion + opacity. Recommended: opacity +
     mild `rotateY` (reference “3D presence”) **without** also scaling if the
     parent `ScaleTransition` already scales the hero (avoid double-scale).
     Wrap **inside** the existing `ScaleTransition` child (`_BadgeHero`), so
     sheet enter scale stays; reveal adds rotateY+opacity only.
3. Reduced motion: child shown at identity transform, opacity 1, no pending
   frames after first layout.
4. Do **not** modify `AchievementBadge` shimmer/pulse controllers.
5. Glow disc stays as sibling behind badge (can be child of the same reveal
   wrapper so glow+badge reveal together).

Exact values:

| Token / value | Source |
|---|---|
| duration | `SacMotion.badgeReveal` = 480ms |
| curve | `SacMotion.easeOut` = `Cubic(0.23, 1, 0.32, 1)` |
| perspective | `setEntry(3, 2, 0.001)` |
| rotateY start | `0.85` rad (~49°) → `0` |
| opacity | `0 → 1` |
| loops | **none** — single `forward()` |
| reduced motion | skip motion; final pose immediately |

## Repo conventions to follow

- Tokens live only in `SacMotion` (`motion_tokens.dart`).
- Update `test/core/animations/motion_tokens_test.dart` if it asserts the set of
  durations (add `badgeReveal` expectation).
- Sheet already uses `SacMotion.reduceMotionOf` — reuse.
- Exemplar for one-shot enter controllers: sheet `_enter` at
  `achievement_detail_sheet.dart:29-46`.

## Steps

1. RED widget test
   `test/features/achievements/presentation/widgets/achievement_badge_reveal_test.dart`:
   - with animations enabled, after pump settle transform ≈ identity / opacity 1
   - with `MediaQuery.disableAnimations: true`, immediate final state
   - after dispose, no pending timers/frames from this controller
   - does not call `repeat`
2. Add `SacMotion.badgeReveal`; update motion_tokens tests.
3. Implement `AchievementBadgeReveal`.
4. Wrap `_BadgeHero` stack (or its return) with the reveal widget.
5. GREEN:
   ```bash
   flutter test test/features/achievements/presentation/widgets/achievement_badge_reveal_test.dart
   flutter test test/features/achievements/presentation/widgets/achievement_badge_test.dart
   flutter test test/core/animations/motion_tokens_test.dart
   ```

## Boundaries

- Do NOT put reveal on grid cards or `AchievementProfileSummary`.
- Do NOT `repeat` or drive Riverpod from animation ticks.
- Do NOT animate layout (`width`/`height`/`padding`).
- Do NOT change unlock overlay (`achievement_unlock_animation.dart`) in this plan.
- Land after **006/007** preferred (same sheet file) — or isolate wrap to
  `_BadgeHero` only to minimize merge conflict.

## Verification

- **Mechanical**: tests above PASS; no `flutter build`.
- **Feel check**:
  - Open detail → badge reveals once (~480ms ease-out), settles still.
  - Re-open same sheet → plays once per mount (OK).
  - Grid scroll → no Y-rotate on grid badges.
  - Reduced motion → badge final pose, no spin.
  - Slow-mo 10%: opacity and rotateY finish together; no flicker of dual scales.
- **Done when**: one-shot reveal only in detail hero; reduced motion safe;
  grid unchanged; tests green.
