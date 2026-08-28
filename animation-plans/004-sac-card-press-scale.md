# 004 — SacCard press scale instead of InkWell splash

- **Status**: DONE
- **Commit**: `0ef841cd`
- **Severity**: HIGH
- **Category**: Physicality
- **Estimated scope**: 1 widget + 1 test file, ~40–70 lines

## Problem

`SacCard` is the high-frequency tap target (Home stats, dashboard tiles, lists). `onTap` uses Material `InkWell` splash. No press scale. `SacButton` already does `scale(0.97)` / 140ms / `SacMotion.easeOut` on pointer-down.

```dart
/* lib/core/widgets/sac_card.dart:139-147 — current */
    if (widget.onTap != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: radius,
          child: content,
        ),
      );
    }
```

Pressable UI without `:active` scale feels deaf. Splash is the wrong language next to Scout press.

## Target

When `onTap != null`:

- Pointer-down: `HapticFeedback.lightImpact()`, scale to `SacMotion.pressScale` (`0.97`).
- Pointer-up / cancel: scale back to `1.0`.
- Duration: `SacMotion.press` = `140ms`.
- Curve: `SacMotion.easeOut` = `Cubic(0.23, 1, 0.32, 1)`.
- Reduced motion (`SacMotion.reduceMotionOf(context) == true`): scale stays `1.0`. Haptic + `onTap` still fire.
- No `InkWell`. No `Material` splash wrapper.
- `Semantics(button: true)` when tappable.
- Entrance fade/scale (`animate: true`) stays outside the press scale — do not nest two competing scales on the same `Transform`.

```dart
/* target press wrap — values must match SacButton */
    if (widget.onTap != null) {
      content = Semantics(
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) {
            HapticFeedback.lightImpact();
            _setPressed(true);
          },
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: (!reduce && _pressed) ? SacMotion.pressScale : 1,
            duration: SacMotion.press,
            curve: SacMotion.easeOut,
            child: content,
          ),
        ),
      );
    }
```

`reduce` is `SacMotion.reduceMotionOf(context)` already read in `build` for entrance. Reuse it. Add `bool _pressed = false` and `_setPressed` like `SacButton`.

Entrance block stays:

```dart
    if (!widget.animate || _reduceMotion == true) return content;

    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        child: content,
      ),
    );
```

So: entrance `ScaleTransition` (0.96 → 1.0) wraps the press `AnimatedScale` (1.0 ↔ 0.97). That order is required.

## Repo conventions to follow

```dart
/* lib/core/widgets/sac_button.dart:404-420 — exemplar */
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: _effectivelyDisabled
              ? null
              : (_) {
                  HapticFeedback.lightImpact();
                  _setPressed(true);
                },
          onTapUp: _effectivelyDisabled ? null : (_) => _setPressed(false),
          onTapCancel:
              _effectivelyDisabled ? null : () => _setPressed(false),
          onTap: _effectivelyDisabled ? null : _handlePressed,
          child: AnimatedScale(
            scale: (!reduce && _pressed) ? SacMotion.pressScale : 1,
            duration: SacMotion.press,
            curve: SacMotion.easeOut,
            child: visual,
          ),
        ),
```

Import `package:flutter/services.dart` for `HapticFeedback`.

Do **not** extract `SacPressable` in this plan. Press lives inside `SacCard`. Feature-local pressables (Support / Materials / Club / Monthly Reports) stay untouched.

## Steps

1. `lib/core/widgets/sac_card.dart`:
   - Add `import 'package:flutter/services.dart';`
   - Add `bool _pressed = false;` and `_setPressed` on `_SacCardState` (no-op if value unchanged).
   - Replace the `InkWell` block with the target wrap.
   - Read `reduce` once at the top of `build` (`SacMotion.reduceMotionOf(context)`) and use it for both press and the existing entrance skip (`_reduceMotion` from `didChangeDependencies` may still gate entrance; do not break that).
2. `test/core/widgets/sac_card_test.dart`:
   - Keep both existing reduced-motion entrance tests.
   - Add: `SacCard(onTap: () {}, child: Text('card'))` inside the same `_MotionHarness` with `disableAnimations: false`. `tester.press` the text (pointer down, do not release). Expect `tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale == SacMotion.pressScale` (`0.97`).
   - Add: same card with `disableAnimations: true`. Pointer down. Expect `AnimatedScale.scale == 1` (or no scale change).
   - Add: `onTap` null → `find.byType(InkWell)` nothing, `find.byType(AnimatedScale)` nothing.
3. Do not edit `DashboardCard` or other SacCard callers. They pick up press automatically.

## Boundaries

- Do NOT change card visuals (radius 16, border, shadow, accent bar).
- Do NOT change entrance tokens (`SacMotion.standard`, `enterScale` 0.96).
- Do NOT create `lib/core/widgets/sac_pressable.dart`.
- Do NOT migrate `SupportPressable` / `MaterialsPressable` / `MonthlyReportPressable` / `_ClubPressable`.
- Do NOT add packages.
- If `onTap` wrapping is no longer `InkWell` when you open the file (already migrated), STOP and report.

## Verification

- **Mechanical**: `flutter test test/core/widgets/sac_card_test.dart` — all pass.
- **Feel check**:
  - Home / Dashboard: press a tappable `SacCard` and hold. Card shrinks to 97% in ~140ms, ease-out (immediate motion). Release: snaps back. No grey ripple.
  - Spam taps: `AnimatedScale` retargets; it must not jump from a keyframe restart.
  - Reduce Motion on: card does not scale; tap still navigates.
  - Card with `onTap: null` (static info): no scale, no ripple.
- **Done when**: zero `InkWell` in `sac_card.dart`; press matches `SacButton` numbers; new tests cover down-scale and reduced motion.
