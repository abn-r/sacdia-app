# 013 — Inventory error icon: enter from 0.96, drop elasticOut

- **Status**: DONE
- **Commit**: `fbee25b1`
- **Severity**: MEDIUM
- **Category**: Easing & duration / cohesion / physicality
- **Estimated scope**: 1 file, ~15–25 lines

## Problem

Inventory error body pops the alert icon with `elasticOut` over 600ms from `0.8`. Cartoon bounce on a failure state. Over the 300ms UI budget. Only `elasticOut` left in `lib/`.

```dart
/* lib/features/inventory/presentation/views/inventory_view.dart:477-482 — current */
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.8, end: 1.0),
            duration: const Duration(milliseconds: 600),
            curve: Curves.elasticOut,
            builder: (context, scale, child) =>
                Transform.scale(scale: scale, child: child),
```

Error is occasional (retry allowed). Delight budget does not apply to failures. Same enter language as unlock / theme picker: already-there disc, ease-out, no spring.

`_ErrorBody` is a `StatelessWidget`. `TweenAnimationBuilder` starts on first build (no `initState`). File already imports `motion_tokens.dart` (skeleton RM, plan 009).

## Target

| Property | Value |
| --- | --- |
| Scale | `SacMotion.enterScale` (`0.96`) → `1.0` |
| Duration | `SacMotion.standard` (`200ms`) |
| Curve | `SacMotion.easeOut` = `Cubic(0.23, 1, 0.32, 1)` |
| Reduced motion | no scale travel — render the icon at `1.0` |

```dart
/* target */
          if (SacMotion.reduceMotionOf(context))
            child
          else
            TweenAnimationBuilder<double>(
              tween: Tween(begin: SacMotion.enterScale, end: 1.0),
              duration: SacMotion.standard,
              curve: SacMotion.easeOut,
              builder: (context, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: child,
            ),
```

Extract the existing 72×72 circle+icon into a local `final icon = Container(...)` (same decoration) and pass it as `child` so RM and motion share one tree. Do not change colors, sizes, or copy.

Keep `TweenAnimationBuilder` for the motion path (one-shot, no controller). Do not add a `StatefulWidget`.

## Repo conventions to follow

- Tokens already in this file.
- Unlock / planned 010: `enterScale` + `easeOut`, never `elasticOut` / `easeOutBack`.
- Plan 009 already fixed `_SkeletonBoxState` in this same file. Do not revert that.

## Steps

1. `lib/features/inventory/presentation/views/inventory_view.dart` `_ErrorBody.build` (~477–498): apply Target. Reuse the current `Container` as the shared child.
2. Leave retry `SacButton` and the two `Text`s untouched.

## Boundaries

- Do NOT restyle the error empty state.
- Do NOT touch `_SkeletonBox` / shimmer (009).
- Do NOT use `Curves.elasticOut`, `easeOutBack`, `begin: 0.8`, or 600ms.
- Do NOT add packages.
- If this `TweenAnimationBuilder` is gone when you open the file, STOP and report.

## Verification

- **Mechanical**: `dart analyze lib/features/inventory/presentation/views/inventory_view.dart`. `rg 'elasticOut' lib` empty. No `flutter build`.
- **Feel check**:
  - Force inventory error (airplane mode + pull). Icon is already ~96% and settles in 200ms. No wobble.
  - Slow Animations: transform only (not layout).
  - Reduce Motion on: icon visible at 1.0 immediately. No scale.
- **Done when**: no `elasticOut` in `lib/`; error icon uses `enterScale` / `standard` / `easeOut`.
