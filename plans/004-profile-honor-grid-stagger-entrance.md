# 004 — Stagger profile honor badge grid entrance

- **Status**: TODO
- **Commit**: `11ee503`
- **Severity**: LOW
- **Category**: Missed opportunities / Cohesion & tokens
- **Estimated scope**: 1 production file, ~25 lines; depends on plans 002–003 only for shared import

## Problem

When Profile honors resolve, every badge in a category appears at once. No entrance
stagger. `my_honors_view` already uses `StaggeredListItem` for a cascading reveal;
Profile grid does not:

```dart
// lib/features/profile/presentation/widgets/profile_honors_section.dart:314-319 — current
itemBuilder: (context, index) {
  return _HonorGridItem(
    userHonor: userHonors[index],
    categoryColor: categoryPaintColor,
  );
},
```

AUDIT.md: group entrances benefit from a **30–80ms** stagger; stagger must never
block interaction. Repo token: `SacMotion.stagger` = 40ms.

## Target

Wrap each grid item with `StaggeredListItem`, using SacMotion durations (not the
widget defaults of 60ms / 350ms which exceed the UI budget):

```dart
// target — _CategorySection GridView.builder itemBuilder
itemBuilder: (context, index) {
  return StaggeredListItem(
    index: index,
    initialDelay: Duration.zero,
    staggerDelay: SacMotion.stagger, // 40ms
    duration: SacMotion.standard,    // 200ms (not default 350)
    slideOffset: 12.0,               // subtle; grid is dense
    child: _HonorGridItem(
      userHonor: userHonors[index],
      categoryColor: categoryPaintColor,
    ),
  );
},
```

Notes:

- `StaggeredListItem` already caps delay index at 5 and honors
  `SacMotion.reduceMotionOf` (skips motion, shows child immediately).
- Do **not** pass `animate: false` unless testing; let the widget read reduce-motion.
- Press scale from plan 002 remains on `_HonorGridItem` inside the stagger wrapper.

## Repo conventions to follow

- Primitive: `lib/core/animations/staggered_list_animation.dart`.
- Tokens: `SacMotion.stagger` (40ms), `SacMotion.standard` (200ms), `SacMotion.easeOut`
  (already used inside `StaggeredListItem`).
- Exemplar (list, not grid — same wrapper):
  `lib/features/honors/presentation/views/my_honors_view.dart:303-307`.
  Profile must prefer SacMotion tokens over that file's 55/350ms literals.

## Steps

1. In `profile_honors_section.dart`, add if missing:
   ```dart
   import 'package:sacdia_app/core/animations/staggered_list_animation.dart';
   import 'package:sacdia_app/core/animations/motion_tokens.dart';
   ```
2. In `_CategorySection`'s `GridView.builder` `itemBuilder`, wrap `_HonorGridItem`
   with `StaggeredListItem` using the target constructor args.
3. Keep `shrinkWrap`, `NeverScrollableScrollPhysics`, and grid delegate unchanged.
4. Do not stagger category headers — only badge cells.
5. Optional: add a focused widget test that pumps ProfileHonorsSection with mock
   user honors and asserts first item opacity < 1 before settle, then settles to
   visible (skip if harness is heavy; feel-check is enough).

## Boundaries

- Do NOT change `StaggeredListItem` defaults globally (would affect my_honors etc.).
- Do NOT stagger across categories with a global index (per-category index is correct).
- Do NOT animate layout size (`transform`/`opacity` only — already true of StaggeredListItem).
- Do NOT block taps during stagger (wrapper must remain hittable; existing
  implementation does not absorb pointers).
- If GridView was replaced since stamp, STOP and report.

## Verification

- **Mechanical**:
  - `dart analyze lib/features/profile/presentation/widgets/profile_honors_section.dart`
  - `flutter test test/features/profile/presentation/utils/profile_honor_navigation_test.dart`
- **Feel check**:
  - Open Profile with several honors in a category: badges cascade left→right/top
    with ~40ms steps, each fade+slide ~200ms, ease-out.
  - Tap a badge mid-stagger: navigation still works immediately.
  - Reduce Motion on: all badges visible with no stagger/slide.
  - Time dilation 5×: confirm no layout jump, only opacity/translate.
- **Done when**: grid items use `StaggeredListItem` with `SacMotion.stagger` +
  `SacMotion.standard`; reduce-motion and taps verified.
