# 009 — Freeze loading skeletons under Reduced Motion

- **Status**: DONE
- **Commit**: `bff0a6bf`
- **Severity**: MEDIUM
- **Category**: Accessibility
- **Estimated scope**: 8 production files, ~60–90 lines

## Problem

Page skeletons start an infinite shimmer in `initState` and never read `SacMotion.reduceMotionOf`. Reduce Motion on → perpetual motion.

```dart
/* lib/features/activities/presentation/widgets/activities_loading_skeleton.dart:29-37 — current */
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _shimmer = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
```

Same `..repeat()` pattern:

| File | Line (controller) |
| --- | --- |
| `lib/features/activities/presentation/widgets/activities_loading_skeleton.dart` | 30–33 |
| `lib/features/activities/presentation/widgets/activity_detail_skeleton.dart` | same 1400ms `repeat()` |
| `lib/features/insurance/presentation/widgets/insurance_loading_skeleton.dart` | 21–24 |
| `lib/features/finances/presentation/widgets/finances_loading_skeleton.dart` | 33–36 |
| `lib/features/classes/presentation/widgets/enroll_previous_class_skeleton.dart` | 33–36 |
| `lib/features/evidence_folder/presentation/widgets/evidence_folder_loading_skeleton.dart` | `repeat()` in `initState` |
| `lib/features/inventory/presentation/views/inventory_view.dart` | `_SkeletonBoxState` ~418–421 (`repeat(reverse: true)`, 1100ms) |
| `lib/features/activities/presentation/views/location_picker_view.dart` | `_ShimmerLineState` ~628–631 (`repeat(reverse: true)`, 900ms) |

Reduced motion means fewer/gentler animations, not zero chrome. Keep the grey boxes. Drop the sweep/pulse.

## Target

Do **not** call `repeat()` in `initState`. Sync in `didChangeDependencies`, same as `RankingSkeleton` (already correct — do not edit it):

```dart
/* lib/features/rankings/presentation/widgets/ranking_skeleton.dart:64-77 — exemplar */
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      if (_controller.isAnimating) {
        _controller.stop();
        _controller.value = 0.9;
      }
    } else {
      if (!_controller.isAnimating) {
        _controller.repeat(reverse: true);
      }
    }
  }
```

For this plan use `SacMotion.reduceMotionOf(context)` (same flag, one helper).

| Mode | Controller |
| --- | --- |
| Reduced motion | `stop()`; freeze at `0` (shimmer sweep) or mid opacity `0.7` (pulse boxes). Boxes stay visible. |
| Motion allowed | `repeat()` or `repeat(reverse: true)` matching what that file does today |

Keep existing durations (1400 / 1100 / 900) and `Curves.easeInOut` on the shimmer itself — constant looping motion may stay `easeInOut` / `linear`. Do not restyle the skeleton layout.

```dart
/* target sync (copy into each State) */
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = SacMotion.reduceMotionOf(context);
    if (reduce) {
      _controller.stop();
      _controller.value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat(); // or repeat(reverse: true) if that file already used reverse
    }
  }
```

Remove `..repeat()` / `..repeat(reverse: true)` from the `initState` constructor chain. Create the controller only; `didChangeDependencies` starts it.

Add `import 'package:sacdia_app/core/animations/motion_tokens.dart';` (or the relative equivalent the file already uses for `core/`).

## Repo conventions to follow

- `RankingSkeleton` — already honors `disableAnimations`. Copy the structure; switch the predicate to `SacMotion.reduceMotionOf`.
- `AchievementBadge._synchronizeAnimations` — stop loops when reduced.
- Tokens file: `lib/core/animations/motion_tokens.dart`.

## Steps

1. Patch the eight files in the table. Preserve `reverse: true` only where it already exists (inventory `_SkeletonBox`, location `_ShimmerLine`).
2. Confirm `rg '\\.\\.repeat\\(' lib --glob '*skeleton*'` no longer sits in `initState` without a Reduced Motion guard. The eight files must go through `didChangeDependencies`.
3. Do not add a shared `SacShimmer` widget in this plan (layout differs per screen).

## Boundaries

- Do NOT edit `ranking_skeleton.dart` (already correct).
- Do NOT edit `notification_card.dart`, `verified_dot.dart`, `va_node.dart` (not page-load skeletons).
- Do NOT edit `achievement_unlock_animation.dart` (plan 006).
- Do NOT change skeleton colors, sizes, or 1400ms period.
- Do NOT add packages.

## Verification

- **Mechanical**: `dart analyze` on the eight files. No `flutter build`.
- **Feel check**:
  - Open Actividades / Seguros / Finanzas while loading (or force the skeleton). Shimmer still sweeps when Reduce Motion is off.
  - Reduce Motion on: boxes visible, gradient/opacity frozen. No loop.
  - Toggle Reduce Motion at runtime if the in-app setting rebuilds `MediaQuery`: loop stops (and can restart if toggled off).
- **Done when**: none of the eight call `repeat()` from `initState`; all eight read `SacMotion.reduceMotionOf`; RankingSkeleton untouched.
