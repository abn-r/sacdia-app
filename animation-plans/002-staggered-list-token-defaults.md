# 002 — Snap staggered-list defaults to SacMotion tokens

- **Status**: DONE
- **Commit**: `0ef841cd`
- **Severity**: HIGH
- **Category**: Easing & duration / purpose & frequency / cohesion
- **Estimated scope**: 1 core file + ~12 call-site token swaps, 1 existing test file, ~80–120 lines

## Problem

Lists open tens of times per day (Honores, Clases, Miembros, Camporees, Certificaciones, Coordinator). Shared defaults are still Duolingo-slow and ignore tokens already used on Login / Club / Resources / Insurance.

```dart
/* lib/core/animations/staggered_list_animation.dart:50-58 — current */
  const StaggeredListItem({
    super.key,
    required this.child,
    required this.index,
    this.initialDelay = Duration.zero,
    this.staggerDelay = const Duration(milliseconds: 60),
    this.duration = const Duration(milliseconds: 350),
    this.slideOffset = 24.0,
    this.animate = true,
  });
```

```dart
/* lib/core/animations/staggered_list_animation.dart:163-174 — current */
  const StaggeredColumn({
    super.key,
    required this.children,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.mainAxisSize = MainAxisSize.min,
    this.initialDelay = const Duration(milliseconds: 80),
    this.staggerDelay = const Duration(milliseconds: 70),
    this.duration = const Duration(milliseconds: 350),
    this.slideOffset = 28.0,
    this.animate = true,
  });
```

Comments still lie:

```dart
/* lib/core/animations/staggered_list_animation.dart:6-8, 26 — current */
/// Duolingo-style staggered list animation utilities.
/// The animation triggers automatically when the widget first builds.
/// [index] controls the stagger delay (50ms per item, capped at 600ms).
```

UI animations must stay under 300ms. Stagger between items must be 30–80ms (token is 40ms). A 350ms item + 60ms stagger makes frequent lists feel slower than Settings / Club.

Call sites that already pass `SacMotion.standard` / `SacMotion.stagger` are correct. Call sites that hardcode 35–65ms still fight the token.

## Target

Exact values (copy, do not invent):

| Token | Value |
| --- | --- |
| `SacMotion.easeOut` | `Cubic(0.23, 1, 0.32, 1)` — already used by the widget; do not change curves |
| `SacMotion.standard` | `Duration(milliseconds: 200)` |
| `SacMotion.stagger` | `Duration(milliseconds: 40)` |
| `slideOffset` default | `8.0` (pixels; `Offset(0, 8/100)` = `Offset(0, 0.08)`) |
| `StaggeredColumn.initialDelay` default | `Duration.zero` |

```dart
/* target — StaggeredListItem defaults */
  const StaggeredListItem({
    super.key,
    required this.child,
    required this.index,
    this.initialDelay = Duration.zero,
    this.staggerDelay = SacMotion.stagger,
    this.duration = SacMotion.standard,
    this.slideOffset = 8.0,
    this.animate = true,
  });
```

```dart
/* target — StaggeredColumn defaults */
  const StaggeredColumn({
    super.key,
    required this.children,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.mainAxisSize = MainAxisSize.min,
    this.initialDelay = Duration.zero,
    this.staggerDelay = SacMotion.stagger,
    this.duration = SacMotion.standard,
    this.slideOffset = 8.0,
    this.animate = true,
  });
```

Keep the existing cap `widget.index.clamp(0, 5)` in `_scheduleStart`. Do not raise it.

Reduced motion behavior already correct (`SacMotion.reduceMotionOf` → skip fade/slide). Do not change it.

## Repo conventions to follow

- Tokens live in `lib/core/animations/motion_tokens.dart`. Do not add new durations.
- Exemplar that already consumes tokens correctly:

```dart
/* lib/features/club/presentation/views/club_view.dart:610-614 — exemplar */
    return StaggeredListItem(
      index: index,
      staggerDelay: SacMotion.stagger,
      duration: SacMotion.standard,
      slideOffset: 8,
```

```dart
/* lib/features/auth/presentation/views/login_view.dart:136-141 — exemplar */
                          StaggeredColumn(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            initialDelay: Duration.zero,
                            staggerDelay: SacMotion.stagger,
                            duration: SacMotion.standard,
                            slideOffset: 8,
```

- Curve stays `SacMotion.easeOut` (`cubic-bezier(0.23, 1, 0.32, 1)`). Never `Curves.easeIn`.

## Steps

1. In `lib/core/animations/staggered_list_animation.dart`:
   - Change the two constructors to the target defaults above.
   - Rewrite the header comments. Remove “Duolingo-style” and “50ms / capped at 600ms”. Say: stagger is `SacMotion.stagger` (40ms) per index, capped at index 5; duration is `SacMotion.standard` (200ms); reduced motion skips movement.
2. Replace leftover hardcoded `staggerDelay:` that is not already `SacMotion.stagger` with `SacMotion.stagger`. Import `motion_tokens.dart` if the file lacks it.

   | File | Current |
   | --- | --- |
   | `lib/features/camporees/presentation/views/camporee_members_view.dart:248` | `Duration(milliseconds: 50)` |
   | `lib/features/camporees/presentation/views/camporees_list_view.dart:81` | `Duration(milliseconds: 45)` |
   | `lib/features/insurance/presentation/views/insurance_view.dart:296` | `Duration(milliseconds: 40)` → token |
   | `lib/features/camporees/presentation/views/camporee_detail_view.dart:466` | `Duration(milliseconds: 35)` |
   | `lib/features/camporees/presentation/views/camporee_detail_view.dart:1134` | `Duration(milliseconds: 40)` → token |
   | `lib/features/honors/presentation/views/my_honors_view.dart:306` | `Duration(milliseconds: 55)` |
   | `lib/features/certifications/presentation/views/my_certifications_view.dart:160` | `Duration(milliseconds: 55)` |
   | `lib/features/certifications/presentation/views/my_certifications_view.dart:197` | `Duration(milliseconds: 55)` |
   | `lib/features/certifications/presentation/views/certifications_list_view.dart:114` | `Duration(milliseconds: 65)` |
   | `lib/features/profile/presentation/views/profile_view.dart:444` | `Duration(milliseconds: 65)` |
   | `lib/features/classes/presentation/views/classes_list_view.dart:175` | `Duration(milliseconds: 65)` |
   | `lib/features/classes/presentation/views/classes_list_view.dart:222` | `Duration(milliseconds: 65)` |
   | `lib/features/rankings/presentation/screens/club_rankings_screen.dart:202` | `Duration(milliseconds: 36)` |

   If a nearby `duration:` is a raw `200` / `350` on that same `StaggeredListItem` / `StaggeredColumn`, switch duration to `SacMotion.standard` and `slideOffset` to `8` only on that widget. Do not hunt unrelated `Duration(milliseconds: 350)` (date-strip scroll is out of scope).
3. Do **not** edit call sites that already pass `SacMotion.stagger` / `SacMotion.standard` (`login_view.dart`, `club_view.dart`, `resources_view.dart`). Leaving them as-is is correct.
4. Keep `test/core/animations/staggered_list_animation_test.dart` passing. It does not assert 350ms. Add one widget test only if you can do it without new helpers: construct `StaggeredListItem(index: 0, child: Text('x'))` and assert the state’s controller duration equals `SacMotion.standard` **or** skip extra tests if that requires making the controller public. Existing reduced-motion tests are enough.

## Boundaries

- Do NOT change `lib/features/activities/presentation/views/activities_list_view.dart` date-strip `Duration(milliseconds: 350)` / `400` (different finding).
- Do NOT change progress fills (`700ms`, `800ms`, `900ms`).
- Do NOT change curves, reduced-motion logic, or the index cap of 5.
- Do NOT add packages.
- Do NOT introduce a new stagger widget.
- If a listed line no longer has `staggerDelay:`, STOP and report that file.

## Verification

- **Mechanical**: `flutter test test/core/animations/staggered_list_animation_test.dart test/features/dashboard/presentation/views/dashboard_view_motion_test.dart` — all pass.
- **Feel check**:
  - Open Honores → Mis honores and Clases. First card starts moving immediately (no 80ms column pause). Cascade is tight: ~40ms between the first 6 items, then the rest appear with the same 200ms ease-out.
  - Open Club / Login (already on tokens). Feel must not get slower or bouncier.
  - In iOS Simulator: Debug → Slow Animations. Confirm slide is ~8% of item height, not a 24–28px hop. Easing starts fast (`ease-out`), never eases in.
  - Enable Reduce Motion in the in-app accessibility setting. Lists appear fully opaque, no slide.
- **Done when**: defaults are the four token values above; leftover hardcoded `staggerDelay` 35–65ms in the table are `SacMotion.stagger`; reduced-motion tests still pass.
