# 010 — Theme picker: enter from 0.96, drop easeOutBack

- **Status**: DONE
- **Commit**: `fbee25b1`
- **Severity**: HIGH
- **Category**: Physicality / easing & duration / cohesion
- **Estimated scope**: 1 file, ~20–40 lines

## Problem

Theme picker is occasional (dialog). Entrance still uses a bounce curve and a 0.82 scale — too close to appearing from nothing, and the only `easeOutBack` left in the app.

```dart
/* lib/features/profile/presentation/views/settings_view.dart:1246-1256 — current */
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _scale = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack)
        .drive(Tween<double>(begin: 0.82, end: 1.0));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut)
        .drive(Tween<double>(begin: 0.0, end: 1.0));
    _controller.forward();
```

`_ScaleFadeIn` wraps `_ThemePickerDialog` (`settings_view.dart:1119`). `showDialog` stays. Controller starts in `initState` (no `BuildContext` for `SacMotion.reduceMotionOf`). File does not import `motion_tokens.dart`.

Nothing in the real world appears from `scale(0.82)` with overshoot. Unlock already left this recipe (`enterScale` → settle, no `easeOutBack`).

## Target

| Property | Value |
| --- | --- |
| Scale | `SacMotion.enterScale` (`0.96`) → `1.0` |
| Fade | `0` → `1` |
| Duration | `SacMotion.standard` (`200ms`) |
| Curve | `SacMotion.easeOut` = `Cubic(0.23, 1, 0.32, 1)` |
| Reduced motion | fade only (`SacMotion.reducedFade` `160ms`). Scale stays `1.0` |

```dart
/* target — motion allowed */
    _controller = AnimationController(
      vsync: this,
      duration: SacMotion.standard,
    );
    _scale = CurvedAnimation(parent: _controller, curve: SacMotion.easeOut)
        .drive(Tween<double>(begin: SacMotion.enterScale, end: 1.0));
    _fade = CurvedAnimation(parent: _controller, curve: SacMotion.easeOut)
        .drive(Tween<double>(begin: 0.0, end: 1.0));
```

Do **not** start `_controller.forward()` in `initState`. Add `_started` and start in `didChangeDependencies` (same as unlock). Under RM set `_controller.duration = SacMotion.reducedFade` then `forward()`.

```dart
/* target build — RM keeps fade, freezes scale */
      builder: (context, child) => FadeTransition(
        opacity: _fade,
        child: ScaleTransition(
          scale: SacMotion.reduceMotionOf(context)
              ? const AlwaysStoppedAnimation(1)
              : _scale,
          child: child,
        ),
      ),
```

Import: `package:sacdia_app/core/animations/motion_tokens.dart` (or `../../../../core/animations/motion_tokens.dart` next to the other `../../../../core/` imports in this file).

## Repo conventions to follow

- Tokens: `lib/core/animations/motion_tokens.dart`.
- Unlock (post-006): `SacMotion.enterScale`, start in `didChangeDependencies`, no `easeOutBack`.
- Dialogs: `SacDialog` is for title+text confirms. This picker is a custom option list — **keep** `showDialog` + `_ThemePickerDialog` chrome.

## Steps

1. `lib/features/profile/presentation/views/settings_view.dart`:
   - Add the motion_tokens import.
   - Change `_ScaleFadeInState` duration, curves, scale tween to Target.
   - Move start to `didChangeDependencies` + `_started`.
   - Reduced motion: fade only.
2. Do not extract `_ScaleFadeIn` to a shared widget (one call site).
3. No new test unless one already pumps this dialog. If none, skip.

## Boundaries

- Do NOT restyle the dialog (radius 20, option rows, cancel `TextButton`).
- Do NOT migrate this dialog to `SacDialog`.
- Do NOT use `Curves.easeOutBack`, `elasticOut`, or `begin: 0.82`.
- Do NOT add packages.
- If `_ScaleFadeIn` is gone when you open the file, STOP and report.

## Verification

- **Mechanical**: `dart analyze lib/features/profile/presentation/views/settings_view.dart` — clean. No `flutter build`.
- **Feel check**:
  - Ajustes → tema. Card is already ~96% and settles. No bounce overshoot.
  - Slow Animations: scale + fade together, 200ms, ease-out (starts moving immediately).
  - Reduce Motion on: fade ~160ms, no scale travel.
- **Done when**: no `easeOutBack` / `0.82` in this file; tokens only; RM skips scale.
