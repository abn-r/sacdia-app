# 011 — Activities date strip: token duration, honor Reduced Motion

- **Status**: DONE
- **Commit**: `fbee25b1`
- **Severity**: MEDIUM
- **Category**: Performance / accessibility / cohesion
- **Estimated scope**: 1 file, ~5–15 lines

## Problem

Toggling card ↔ chronological view animates the date strip height with raw Material numbers. `AnimatedSize` is layout (allowed here — the strip is 76px and already clipped). The leftover is the 300ms / `Curves.easeInOut` pair and no Reduced Motion.

```dart
/* lib/features/activities/presentation/views/activities_list_view.dart:719-725 — current */
                return ClipRect(
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: isChronologicalView
                        ? const SizedBox(height: 0)
                        : ValueListenableBuilder<DateTime?>(
```

File already imports `motion_tokens.dart`. Morph-on-screen → ease-in-out is the right *kind* of curve. 300ms is over `SacMotion.standard` (200ms) and the 300ms UI ceiling.

Toggle is occasional (not 100+/day). Keep the size animation. Snap tokens. Instant under RM.

## Target

| Property | Value |
| --- | --- |
| Duration (motion allowed) | `SacMotion.standard` (`200ms`) |
| Curve | `SacMotion.easeInOut` = `Cubic(0.77, 0, 0.175, 1)` |
| Reduced motion | `Duration.zero` (strip appears/disappears, no height travel) |

```dart
/* target */
                return ClipRect(
                  child: AnimatedSize(
                    duration: SacMotion.reduceMotionOf(context)
                        ? Duration.zero
                        : SacMotion.standard,
                    curve: SacMotion.easeInOut,
                    child: isChronologicalView
                        ? const SizedBox(height: 0)
                        : ValueListenableBuilder<DateTime?>(
```

Keep `ClipRect`. Keep the `SizedBox(height: 0)` collapsed child. Do not replace `AnimatedSize` with fade/slide.

## Repo conventions to follow

- Tokens already imported in this file.
- Morph on screen → `SacMotion.easeInOut` (same decision as AUDIT moving/morphing).
- RM duration zero on layout animations: same idea as `AnimationStyle.noAnimation` on sheets.

## Steps

1. `lib/features/activities/presentation/views/activities_list_view.dart` ~720–722: swap duration/curve as Target.
2. No other `AnimatedSize` in this file. Stop after this one.

## Boundaries

- Do NOT restyle the strip, day cells, or the view-toggle button.
- Do NOT replace `InkWell` on day cells (out of scope).
- Do NOT edit `create_activity_view.dart` / `edit_activity_view.dart` `AnimatedSize` (form expanders; not this finding).
- Do NOT add packages.
- If this `AnimatedSize` is gone when you open the file, STOP and report.

## Verification

- **Mechanical**: `dart analyze lib/features/activities/presentation/views/activities_list_view.dart` — clean. No `flutter build`.
- **Feel check**:
  - Actividades → toggle lista/tarjetas. Strip height eases in 200ms, no bounce.
  - Slow Animations: only height, clipped, no sibling jump outside the clip.
  - Reduce Motion on: strip snaps. No 200ms collapse.
- **Done when**: this call uses `SacMotion.standard` + `easeInOut`; RM is `Duration.zero`.
