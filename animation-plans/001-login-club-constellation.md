# 001 — Add floating club emblems on login laterals

- **Status**: DONE
- **Commit**: `eb9a994` (working tree already has the uncommitted login/splash redesign — apply this plan on top of those files, do not revert them)
- **Severity**: LOW
- **Category**: Missed opportunities (rare/first-time delight) + Accessibility + Performance
- **Estimated scope**: 3 files (1 new widget, 1 login wrap, 1 motion token)

## Precondition (hard stop)

`assets/img/logo-jovenes-adventistas.png` **must exist** before coding.

If that file is missing: **STOP and report**. Do not substitute `A3.png`, `logo_ave.png`, or any other club mark. Do not download a logo.

The other three assets already exist and **must** be the color versions (white canvas):

| Slot | Asset |
| --- | --- |
| Left / top | `assets/img/logo_aventureros_color.png` |
| Left / bottom | `assets/img/logo-guias-mayores.png` |
| Right / top | `assets/img/logo_conquistadores_color.png` |
| Right / bottom | `assets/img/logo-jovenes-adventistas.png` |

Do **not** use `assets/img/logo-conquistadores.png` (white-on-black, unreadable on the white login).

## Problem

Login is a rare/first-time surface. It currently has no club identity in the margins — only the SACDIA app icon and the form. The user asked for four ministry emblems floating on the laterals.

Current scaffold is a single `SafeArea` form with no overlay:

```dart
/* lib/features/auth/presentation/views/login_view.dart:111 — current */
    return Scaffold(
      backgroundColor: context.sac.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
```

A looping float is allowed here (login is not 100+/day). It is **not** allowed to:

- use `scale(0)` on enter
- use `ease-in`
- run a ~5s cycle (≈ 0.2 Hz — vestibular danger)
- animate layout properties (`left`/`top`/`padding`)
- steal taps from `SacTextField`
- keep drifting while the keyboard is open
- ignore Reduced Motion

## Target

Decorative constellation **behind** the form. `IgnorePointer` + `ExcludeSemantics`. Animate **only** `transform` and `opacity`.

### Enter (once)

- Duration: `SacMotion.standard` = `200ms`
- Curve: `SacMotion.easeOut` = `Cubic(0.23, 1, 0.32, 1)` which is `cubic-bezier(0.23, 1, 0.32, 1)`
- From: `opacity: 0` + `scale: SacMotion.enterScale` (`0.96`)
- To: `opacity: 0.38` + `scale: 1.0`
- Stagger: `SacMotion.stagger` = `40ms` between emblems (order: Aventureros → Conquistadores → Guías Mayores → Jóvenes Adventistas)
- Single enter controller duration: `200 + 3*40 = 320ms`
- Interval for index `i` (0..3): start `i * 40 / 320`, end `(i * 40 + 200) / 320`, curve `SacMotion.easeOut`

### Idle drift (loop)

- One `AnimationController`, `duration: Duration(milliseconds: 3200)`, `repeat()` (not `reverse:`), time curve **linear**
- Position via sine (smooth turnaround, not a ping-pong brick wall):
  - `dy = sin(2 * pi * ((t + phase) % 1.0)) * 6.0`  → amplitude **6.0 px**
  - `rotation = sin(2 * pi * ((t + phase) % 1.0) + 0.8) * 0.035`  → ≈ 2°
- Phases: `0.00`, `0.25`, `0.50`, `0.75` so the four emblems never bob in unison
- Period 3200ms ≈ 0.31 Hz — **not** 5000ms / 0.2 Hz
- Apply with `Transform.translate` + `Transform.rotate` (or one `Transform` with `Matrix4`). Never animate `Positioned.top`.

### Reduced Motion

`SacMotion.reduceMotionOf(context) == true`:

- Do **not** start the drift controller
- Enter is opacity only, duration `SacMotion.reducedFade` (`160ms`), curve `SacMotion.easeOut`
- Resting opacity `0.28`, `scale: 1`, `offset: Offset.zero`, `rotation: 0`

### Keyboard / landscape

- If `MediaQuery.viewInsetsOf(context).bottom > 0`: opacity of the whole constellation → `0` in `SacMotion.reducedFade` (`160ms`) `SacMotion.easeOut`. Do not keep drifting visually (controller may keep ticking; wrap with `IgnorePointer` + `Offstage`/`opacity 0`).
- If `Responsive.isLandscape(context) && Responsive.isCompactHeight(context)`: do not build the constellation (`SizedBox.shrink()`).

### Layout (peek from edges, behind the form)

Use `Positioned` for **resting** layout only (static, not animated):

```
safe = MediaQuery.paddingOf(context)
size = 52 if width < 360; 64 otherwise; 72 if width >= 600

Aventureros:     left: -18,  top:    safe.top + 72
Conquistadores:  right: -18, top:    safe.top + 108
Guías Mayores:   left: 10,   bottom: safe.bottom + 108
Jóvenes Adv.:    right: 10,  bottom: safe.bottom + 96
```

Emblem widget: `Image.asset` with `fit: BoxFit.contain`, `filterQuality: FilterQuality.medium`, `cacheWidth: (size * dpr).round().clamp(64, 256)`, `excludeFromSemantics: true`.

Idle opacity `0.38` is on the emblem (not the image color). Do not add drop shadows that animate.

## Repo conventions to follow

- Motion tokens live in `lib/core/animations/motion_tokens.dart`. Add **one** new duration there; do not invent a second easing file.
- Reduced Motion gate exemplar: `lib/core/animations/staggered_list_animation.dart` (`SacMotion.reduceMotionOf` + skip movement).
- Auth widgets live in `lib/features/auth/presentation/widgets/`. Imitate `sac_brand_mark.dart` (stateless mark, asset path as `static const`).
- Do not restyle `SacTextField`. Do not change splash.

Add to `SacMotion`:

```dart
  /// Decorative idle drift on rare surfaces (login constellation).
  /// 3200ms ≈ 0.31 Hz — keep away from ~0.2 Hz / 5000ms.
  static const Duration idleDrift = Duration(milliseconds: 3200);
```

## Steps

1. Confirm `assets/img/logo-jovenes-adventistas.png` exists. If not, STOP.

2. In `lib/core/animations/motion_tokens.dart`, add `idleDrift` exactly as in Target / Repo conventions. Do not change existing token values.

3. Create `lib/features/auth/presentation/widgets/login_club_constellation.dart` with this structure (executor may fill imports; behavior must match Target exactly):

```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/utils/responsive.dart';

class LoginClubConstellation extends StatefulWidget {
  const LoginClubConstellation({super.key});

  @override
  State<LoginClubConstellation> createState() => _LoginClubConstellationState();
}

class _EmblemSpec {
  const _EmblemSpec({
    required this.asset,
    required this.phase,
    required this.left,
    required this.right,
    required this.top,
    required this.bottom,
  });

  final String asset;
  final double phase;
  final double? left;
  final double? right;
  final double? top;
  final double? bottom;
}

class _LoginClubConstellationState extends State<LoginClubConstellation>
    with TickerProviderStateMixin {
  static const _enterSpan = 200.0;
  static const _staggerMs = 40.0;
  static const _enterTotalMs = 320.0; // 200 + 3*40
  static const _amplitude = 6.0;
  static const _rotation = 0.035;
  static const _idleOpacity = 0.38;
  static const _reducedOpacity = 0.28;

  late final AnimationController _enter;
  late final AnimationController _drift;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _drift = AnimationController(
      vsync: this,
      duration: SacMotion.idleDrift,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = SacMotion.reduceMotionOf(context);
    if (reduce) {
      _drift.stop();
      _enter.duration = SacMotion.reducedFade;
      if (!_enter.isCompleted) _enter.forward();
    } else {
      _enter.duration = const Duration(milliseconds: 320);
      if (!_enter.isCompleted) _enter.forward();
      if (!_drift.isAnimating) _drift.repeat();
    }
  }

  @override
  void dispose() {
    _enter.dispose();
    _drift.dispose();
    super.dispose();
  }

  // build(): if landscape+compact height → shrink.
  // Else Stack of 4 Positioned emblems.
  // Keyboard: AnimatedOpacity 160ms SacMotion.easeOut, opacity 0 when viewInsets.bottom > 0.
  // Each emblem: FadeTransition + ScaleTransition on enter interval,
  // then Transform.translate/rotate from _drift.
}
```

Enter interval for index `i`:

```dart
final start = (i * _staggerMs) / _enterTotalMs;
final end = (i * _staggerMs + _enterSpan) / _enterTotalMs;
final interval = Interval(start, end.clamp(0.0, 1.0), curve: SacMotion.easeOut);
```

Under reduced motion, skip `ScaleTransition` and skip `Transform` drift; only fade to `_reducedOpacity`.

4. Wrap `LoginView` scaffold body. In `lib/features/auth/presentation/views/login_view.dart`:

Replace:

```dart
    return Scaffold(
      backgroundColor: context.sac.background,
      body: SafeArea(
        child: Center(
```

with:

```dart
    return Scaffold(
      backgroundColor: context.sac.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const LoginClubConstellation(),
          SafeArea(
            child: Center(
```

Close the extra `Stack` / `children` at the end of the `Scaffold` body (add one `], ),` before the scaffold closes). Import `login_club_constellation.dart`. Do not move form widgets. Do not change `SacTextField`, button, or brand mark.

5. Do not edit splash, register, forgot-password, `SacTextField`, `SacButton`, native splash assets, or insurance WIP files.

## Boundaries

- Do NOT touch `lib/features/auth/presentation/views/splash_view.dart`.
- Do NOT restyle `SacTextField` or change login colors/tokens.
- Do NOT add packages (no Rive, no Lottie).
- Do NOT use `AnimationController.repeat(reverse: true)` for the drift.
- Do NOT use `Curves.easeIn`, `Curves.easeOutBack`, or `scale: 0`.
- Do NOT animate `Positioned` left/top/bottom/right.
- Do NOT set `IgnorePointer` to `false` — emblems are never tappable.
- If the JA asset is missing, STOP.

## Verification

- **Mechanical**: `dart analyze lib/features/auth/presentation/widgets/login_club_constellation.dart lib/features/auth/presentation/views/login_view.dart lib/core/animations/motion_tokens.dart` → `No issues found!`. Do not run a full `flutter build`.
- **Feel check** (login, portrait iPhone):
  - Four emblems peek from the laterals: Aventureros top-left, Guías Mayores bottom-left, Conquistadores top-right, Jóvenes Adventistas bottom-right.
  - Form stays fully tappable; tapping a logo area focuses the field underneath, never the image.
  - Enter: they do **not** pop from nothing — a visible 0.96 scale + fade, 40ms apart, ~200ms each.
  - Idle: slow independent bob (~6px), not a synchronized wave, not a 5-second pendulum.
  - Slow-mo (time dilation 0.25 in Flutter DevTools): sine turnaround is round, no linear ping-pong hitch at the peak.
  - Open the keyboard: constellation fades out in ~160ms; dismiss keyboard: fades back. Fields never covered.
  - Landscape phone: constellation gone.
  - Settings → Accessibility → Motion → Reduce: logos appear with a short fade, then sit still.
- **Done when**: all four color emblems visible on portrait login, form usability unchanged, Reduced Motion has zero translation, `dart analyze` clean.
