# 006 — Achievement unlock: enter from 0.96, honor Reduced Motion

- **Status**: DONE
- **Commit**: `bff0a6bf`
- **Severity**: HIGH
- **Category**: Physicality / accessibility
- **Estimated scope**: 1 file, ~40–70 lines

## Problem

Unlock is rare (delight allowed). The badge still appears from nothing and ignores Reduced Motion. Glow animates `width`/`height` (layout), not `transform`.

```dart
/* lib/features/achievements/presentation/widgets/achievement_unlock_animation.dart:70-113 — current */
    _badgeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    // ...
    // Badge: 0 → 1.2 → 1.0 (bounceOut style)
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.2)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 70,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.2, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 30,
      ),
    ]).animate(_badgeController);

    _badgeController.forward().then((_) {
      if (mounted) _textController.forward();
      if (mounted) _particlesController.forward();
    });
```

```dart
/* lib/features/achievements/presentation/widgets/achievement_unlock_animation.dart:163-168 — current */
                    AnimatedBuilder(
                      animation: _badgeController,
                      builder: (context, _) => Container(
                        width: 130 * _scaleAnimation.value,
                        height: 130 * _scaleAnimation.value,
```

Nothing in the real world appears from `scale(0)`. `easeOutBack` from 0 overshoots from nowhere. Rare ≠ exempt from `scale(0)` or Reduced Motion.

File does not import `motion_tokens.dart`. Controllers start in `initState` (no `BuildContext` for `SacMotion.reduceMotionOf`).

## Target

| Property | Value |
| --- | --- |
| Badge enter scale | `SacMotion.enterScale` (`0.96`) → `1.06` → `1.0` |
| Badge duration | `500ms` (rare celebration; stay in the 200–500ms modal band) |
| Enter curve | `SacMotion.easeOut` = `Cubic(0.23, 1, 0.32, 1)` |
| Settle curve | `SacMotion.easeInOut` = `Cubic(0.77, 0, 0.175, 1)` |
| Text fade | `SacMotion.standard` (`200ms`), `SacMotion.easeOut` |
| Particles | keep 1200ms **only** when motion is allowed |
| Glow | fixed `130×130`, wrap in `Transform.scale` (same animation as badge). Never animate `width`/`height` |
| Reduced motion | no scale, no particles, no glow size change. Barrier + badge + text fade in `SacMotion.reducedFade` (`160ms`), `SacMotion.easeOut` |

```dart
/* target — motion allowed */
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: SacMotion.enterScale, end: 1.06)
            .chain(CurveTween(curve: SacMotion.easeOut)),
        weight: 70,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.06, end: 1.0)
            .chain(CurveTween(curve: SacMotion.easeInOut)),
        weight: 30,
      ),
    ]).animate(_badgeController);
```

```dart
/* target — glow (transform only) */
                    Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Container(
                        width: 130,
                        height: 130,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [ /* same shadow */ ],
                        ),
                      ),
                    ),
```

Do **not** start controllers in `initState`. Mirror `AchievementBadge`:

```dart
/* target start */
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = SacMotion.reduceMotionOf(context);
    if (reduce) {
      _badgeController.value = 1;
      _textController.forward();
      // do not start _particlesController
      return;
    }
    if (!_started) {
      _started = true;
      _badgeController.forward().then((_) {
        if (!mounted) return;
        _textController.forward();
        _particlesController.forward();
      });
    }
  }
```

Keep tap-to-dismiss and the 3s auto-dismiss.

Update the file header comment: drop “desde 0 → 1.2” / “bounceOut”.

## Repo conventions to follow

- Tokens: `lib/core/animations/motion_tokens.dart`.
- Reduced-motion start: `lib/features/achievements/presentation/widgets/achievement_badge.dart` `_synchronizeAnimations` (stop loops when `SacMotion.reduceMotionOf` is true).
- Press/enter scale already shipped: `SacMotion.enterScale` / `pressScale`. Do not invent `0.9` or `0`.

Import: `package:sacdia_app/core/animations/motion_tokens.dart`

## Steps

1. `lib/features/achievements/presentation/widgets/achievement_unlock_animation.dart`:
   - Add the motion_tokens import.
   - Change badge tween + duration + curves to Target.
   - Change text controller duration to `SacMotion.standard`, curve `SacMotion.easeOut`.
   - Move start logic to `didChangeDependencies` as above. Guard with `_started` so it does not re-fire.
   - Glow: fixed 130, `Transform.scale`.
   - Reduced motion: skip particles widget (or paint with `progress == 0` and never forward that controller).
   - Rewrite the class doc comment.
2. No new test file unless one already mounts this overlay under `test/features/achievements`. If none, skip.
3. Do not change `AchievementBadge` shimmer/pulse (already respects Reduced Motion).

## Boundaries

- Do NOT restyle copy, colors, particle count, or the 3s dismiss.
- Do NOT use `Curves.easeOutBack`, `elasticOut`, or `begin: 0.0` for scale.
- Do NOT animate layout (`width`, `height`, `padding`).
- Do NOT add packages.
- If the scale tween no longer starts at `0.0` when you open the file, STOP and report.

## Verification

- **Mechanical**: `dart analyze lib/features/achievements/presentation/widgets/achievement_unlock_animation.dart` — clean. No `flutter build`.
- **Feel check**:
  - Trigger an unlock (or pump the overlay in a harness). Badge is already a disc at 96% scale, then settles. No pop-from-void. Overshoot to 1.06 is slight, not a bounce cartoon.
  - Slow Animations: glow and badge scale together; no box growing via layout.
  - Reduce Motion on: badge + text fade only (~160ms). No particles, no scale travel.
- **Done when**: no `begin: 0.0` scale; glow uses transform; Reduced Motion skips movement; tokens only.
