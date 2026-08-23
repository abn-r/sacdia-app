# 015 — Leftover list/step motion: tokens, drop Material cubics

- **Status**: DONE
- **Commit**: `013d03cc`
- **Severity**: MEDIUM
- **Category**: Easing & duration / cohesion / accessibility
- **Estimated scope**: 5 files, ~40–70 lines

## Problem

001–014 closed bounce, sheets, press, skeletons, `AnimatedSize`. Frequent list/step motion still uses raw Material cubics and durations over the 300ms UI ceiling.

```dart
/* lib/features/activities/presentation/views/activities_list_view.dart:159-176 — current */
      _dateScrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      // ...
      _dateScrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
```

```dart
/* lib/features/activities/presentation/views/activities_list_view.dart:406-414 — current */
                            _chronoScrollController.animateTo(
                              ...
                              duration: const Duration(milliseconds: 450),
                              curve: Curves.easeOut,
```

```dart
/* lib/features/monthly_reports/presentation/widgets/monthly_report_motion.dart:31-55 — current */
        Timer(Duration(milliseconds: (widget.index * 36).clamp(0, 144)), () {
    // ...
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      // fade 180ms, Curves.easeOut
```

```dart
/* lib/features/post_registration/presentation/views/post_registration_shell.dart:101-105 — current */
    _pageController?.animateToPage(
      step - 1,
      duration: const Duration(milliseconds: 340),
      curve: Curves.easeOutCubic,
    );
```

```dart
/* lib/features/classes/presentation/widgets/module_expansion_tile.dart:244-255 — current */
    _chevronController = AnimationController(
      duration: const Duration(milliseconds: 200),
    );
    // Curves.easeOut (not SacMotion.easeOut)
```

Date-strip / chrono scroll is tens of times per visit. 350–450ms feels late. Monthly-report entrance still has its own stagger (36ms) after 002 tokenized `StaggeredListItem`. Wizard step and class-module expand are the same leftover cubic.

Do **not** touch: skeleton shimmer `Curves.easeInOut` (009), progress rings / upload bars, celebration, parallax, `AnimatedSize` (014).

## Target

| Surface | Duration | Curve | Reduced motion |
| --- | --- | --- | --- |
| Date-strip `animateTo` (today + index) | `SacMotion.modal` (`240ms`) | `SacMotion.easeInOut` | `jumpTo` |
| Chrono `animateTo` today | `SacMotion.modal` (`240ms`) | `SacMotion.easeOut` | `jumpTo` |
| `MonthlyReportEntrance` delay | `index * SacMotion.stagger` (`40ms`), clamp 160 | — | skip slide/fade (already) |
| `MonthlyReportEntrance` slide | `SacMotion.standard` (`200ms`) | `SacMotion.easeOut` | existing early return |
| `MonthlyReportEntrance` fade | `SacMotion.standard` (`200ms`) | `SacMotion.easeOut` | existing early return |
| Post-reg `animateToPage` | `SacMotion.modal` (`240ms`) | `SacMotion.easeOut` | `jumpToPage` |
| Module expand / chevron | `SacMotion.standard` (`200ms`) | `SacMotion.easeOut` | `duration = Duration.zero` in `didChangeDependencies` or snap `value` |

```dart
/* target — date strip */
    if (animate && !SacMotion.reduceMotionOf(context)) {
      _dateScrollController.animateTo(
        offset,
        duration: SacMotion.modal,
        curve: SacMotion.easeInOut,
      );
    } else {
      _dateScrollController.jumpTo(offset);
    }
```

`_scrollToToday` / `_scrollToIndex` need `BuildContext` — they are methods on `State`, so `context` is available.

```dart
/* target — monthly entrance delay */
        Timer(SacMotion.stagger * widget.index, () {
```

`Duration * int` works (`stagger * index`). Cap: `SacMotion.stagger * widget.index` is enough (lists are short). Drop the 144ms clamp or keep `.clamp` via `Duration(milliseconds: (index * 40).clamp(0, 160))`.

Use `SacMotion.reduceMotionOf` in `MonthlyReportEntrance`. Delete `_reduceMotion` at the bottom of `monthly_report_motion.dart` if nothing else calls it.

```dart
/* target — wizard */
    if (SacMotion.reduceMotionOf(context)) {
      _pageController?.jumpToPage(step - 1);
    } else {
      _pageController?.animateToPage(
        step - 1,
        duration: SacMotion.modal,
        curve: SacMotion.easeOut,
      );
    }
```

Module tile: duration `SacMotion.standard`, curve `SacMotion.easeOut`. In `didChangeDependencies`, if RM: `_chevronController.duration = Duration.zero`.

Imports: `motion_tokens.dart` where missing (`monthly_report_motion.dart`, `post_registration_shell.dart`, `module_expansion_tile.dart`). Activities list already imports it.

## Repo conventions to follow

- Tokens: `lib/core/animations/motion_tokens.dart`.
- 002: stagger `40ms`, list enter `standard` + `easeOut`.
- 011/014: RM → no travel (`Duration.zero` / `jumpTo`).
- Scroll-on-screen → `easeInOut`. Enter/step → `easeOut`.

## Steps

1. `activities_list_view.dart` — three `animateTo` sites as Target.
2. `monthly_report_motion.dart` — entrance tokens + `SacMotion.reduceMotionOf`; delete unused `_reduceMotion`.
3. `post_registration_shell.dart` — `animateToPage` as Target. Add import.
4. `module_expansion_tile.dart` — duration/curve + RM. Add import.
5. `rg 'easeOutCubic' lib` — remaining hits must be progress/celebration/parallax/comments, not these five files.

## Boundaries

- Do NOT retune skeleton periods (1400ms) or `Curves.easeInOut` on shimmer.
- Do NOT edit `upload_progress_sheet.dart` progress tweens, `sac_progress_ring`, `animated_counter`, `celebration_overlay`, `credential_parallax`.
- Do NOT edit FAQ/units `AnimatedSize`.
- Do NOT add packages.
- If a listed `animateTo` is gone, STOP and report.

## Verification

- **Mechanical**: `dart analyze` on the five files. No `flutter build`.
- **Feel check**:
  - Actividades: tap a day / toggle chrono. Strip and list settle in ~240ms, start moving immediately. RM: jump, no glide.
  - Informe mensual list: rows enter 200ms, 40ms stagger. RM: instant.
  - Post-registro next/back: page 240ms ease-out. RM: jump.
  - Clase → módulo expand: chevron + body 200ms ease-out. RM: snap.
- **Done when**: no 350/400/450/340/`easeOutCubic` on these five surfaces; tokens only.
