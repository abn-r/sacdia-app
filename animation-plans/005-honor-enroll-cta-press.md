# 005 — Honor enroll CTA: press on down, enroll immediately

- **Status**: DONE
- **Commit**: `0ef841cd`
- **Severity**: HIGH
- **Category**: Interruptibility / purpose & frequency
- **Estimated scope**: 1 private widget in one file, ~40 lines

## Problem

`_EnrollCtaButton` plays a full press animation **and waits for it** before calling enroll. Decoration blocks work. Release is not snappy. There is no pointer-down feedback — only an awaited reverse/forward after tap.

```dart
/* lib/features/honors/presentation/views/honor_detail_view.dart:3343-3380 — current */
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      lowerBound: 0.97,
      upperBound: 1.0,
      value: 1.0,
    );
    _pressScale = _pressController;
    // ...
  Future<void> _onTap() async {
    await _pressController.reverse();
    await _pressController.forward();
    HapticFeedback.mediumImpact();

    final authState = ref.read(authNotifierProvider);
    final userId = authState.value?.id;
    if (userId == null) return;

    await ref
        .read(honorEnrollmentNotifierProvider.notifier)
        .enrollInHonor(userId, widget.honorId);
  }
  // build: ScaleTransition(scale: _pressScale, child: GestureDetector(onTap: _onTap, ...))
```

Asymmetric rule: press feedback is 100–160ms on pointer-down; the system response (enroll) must not wait. `ease-in` is forbidden; this path is worse — it serializes animation before the request.

File already imports `package:sacdia_app/core/animations/motion_tokens.dart` and `package:flutter/services.dart`.

## Target

Drop `SingleTickerProviderStateMixin`, `AnimationController`, and `ScaleTransition`.

Pointer-down scale like `SacButton`. Enroll starts in `onTap` with no `await` on animation.

| Property | Value |
| --- | --- |
| Press scale | `SacMotion.pressScale` = `0.97` |
| Duration | `SacMotion.press` = `140ms` |
| Curve | `SacMotion.easeOut` = `Cubic(0.23, 1, 0.32, 1)` |
| Haptic | `HapticFeedback.lightImpact()` on **down** (same as `SacButton`; replace `mediumImpact` after animation) |
| Reduced motion | scale stays `1.0`; enroll still runs |

Keep the existing visual container (category color, height 48, radius 14, shadow, label `'honors.detail.enroll_cta'.tr()`). Motion only.

```dart
/* target — _EnrollCtaButtonState */
class _EnrollCtaButtonState extends ConsumerState<_EnrollCtaButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  Future<void> _onTap() async {
    final authState = ref.read(authNotifierProvider);
    final userId = authState.value?.id;
    if (userId == null) return;

    await ref
        .read(honorEnrollmentNotifierProvider.notifier)
        .enrollInHonor(userId, widget.honorId);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = SacMotion.reduceMotionOf(context);
    final foregroundColor = _heroForegroundColor(context, widget.categoryColor);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        HapticFeedback.lightImpact();
        _setPressed(true);
      },
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: _onTap,
      child: AnimatedScale(
        scale: (!reduce && _pressed) ? SacMotion.pressScale : 1,
        duration: SacMotion.press,
        curve: SacMotion.easeOut,
        child: Container(
          width: double.infinity,
          height: 48,
          decoration: BoxDecoration(
            color: widget.categoryColor,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: widget.categoryColor.withValues(alpha: 0.30),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            'honors.detail.enroll_cta'.tr(),
            style: TextStyle(
              color: foregroundColor,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}
```

Do not convert this CTA to `SacButton` (category color + custom shadow would become a restyle).

`_LoadingCtaButton` stays as-is.

## Repo conventions to follow

```dart
/* lib/core/widgets/sac_button.dart:404-420 — exemplar */
          onTapDown: ... HapticFeedback.lightImpact(); _setPressed(true);
          child: AnimatedScale(
            scale: (!reduce && _pressed) ? SacMotion.pressScale : 1,
            duration: SacMotion.press,
            curve: SacMotion.easeOut,
```

Same numbers. Same down/up/cancel. No `await` before the real action.

## Steps

1. In `lib/features/honors/presentation/views/honor_detail_view.dart`, replace `_EnrollCtaButtonState` (starts ~line 3335) with the target class. Remove `initState` / `dispose` / ticker mixin.
2. Confirm `_onTap` no longer awaits any animation. Keep the enroll notifier call identical.
3. No new test file required unless an honor-detail widget test already mounts this CTA — if you find one under `test/features/honors`, update it so it does not `pump` 150ms+150ms waiting for reverse/forward. If none exists, skip.

## Boundaries

- Do NOT restyle the CTA (colors, radius, height, copy).
- Do NOT change enrollment provider / API.
- Do NOT touch `_HonorHeroMotion`, badge `ScaleTransition`, or the 800ms stat-card stagger (out of scope).
- Do NOT add packages.
- Do NOT use `Curves.easeOutBack`, `elasticOut`, or `scale` from `0`.
- If `_onTap` no longer `await`s the controller when you open the file, STOP and report.

## Verification

- **Mechanical**: `dart analyze lib/features/honors/presentation/views/honor_detail_view.dart` — no issues on the edited class. Full `flutter build` is forbidden unless the user later asks.
- **Feel check**:
  - Honor detail, not enrolled: finger down — CTA scales to 97% in 140ms, ease-out, haptic on down. Finger up — scale returns. Network enroll starts on tap, **not** after ~300ms of animation.
  - Tap and immediately leave the screen (if still possible): no controller leak (controller is gone).
  - Reduce Motion on: no scale; enroll still runs.
  - Slow Animations: press is only scale, never a delayed “play then work” sequence.
- **Done when**: no `AnimationController` on `_EnrollCtaButtonState`; enroll is not gated on press animation; press numbers match `SacButton`.
