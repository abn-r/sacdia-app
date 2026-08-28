# 008 — One press primitive: SacPressable

- **Status**: DONE
- **Commit**: `bff0a6bf`
- **Severity**: MEDIUM
- **Category**: Cohesion / physicality
- **Estimated scope**: 1 new widget + 6 feature files, delete 1 file, ~80–120 lines

## Problem

`SacButton` and `SacCard` already press at `SacMotion.pressScale` (`0.97`) / `SacMotion.press` (`140ms`) / `SacMotion.easeOut`. Five feature-local copies disagree on curve, duration, and scale.

```dart
/* lib/features/materials/presentation/widgets/materials_pressable.dart:38-42 — current */
      child: AnimatedScale(
        scale: (!reduce && _pressed) ? widget.pressedScale : 1,
        duration: SacMotion.press,
        curve: Curves.easeOut, // not SacMotion.easeOut
```

```dart
/* lib/features/monthly_reports/presentation/widgets/monthly_report_motion.dart:97-101 — current */
      child: AnimatedScale(
        scale: (!reduce && _pressed) ? widget.pressedScale : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
```

```dart
/* lib/features/camporees/presentation/views/camporees_list_view.dart:346-350 — current */
      child: AnimatedScale(
        scale: (!reduce && _pressed) ? 0.98 : 1,
        duration: SacMotion.press,
        curve: Curves.easeOut,
```

```dart
/* lib/features/support/presentation/widgets/support_chrome.dart:72-88 — current */
    Widget child = AnimatedScale(
      scale: (!reduce && _pressed && widget.enabled) ? SacMotion.pressScale : 1,
      duration: SacMotion.press,
      curve: SacMotion.easeOut,
      child: widget.child,
    );
    // haptic is selectionClick on tap, not lightImpact on down
```

```dart
/* lib/features/club/presentation/views/club_view.dart:696-705 — current */
    return Listener(
      onPointerDown: widget.enabled ? (_) => _setPressed(true) : null,
      // listen-only: must not steal SacTextField's tap
      child: AnimatedScale(
        scale: (!reduce && _pressed) ? 0.97 : 1,
```

One press must feel like one press.

## Target

New `SacPressable` in `lib/core/widgets/sac_pressable.dart`.

| Property | Value |
| --- | --- |
| Scale | `SacMotion.pressScale` (`0.97`) |
| Duration | `SacMotion.press` (`140ms`) |
| Curve | `SacMotion.easeOut` = `Cubic(0.23, 1, 0.32, 1)` |
| Haptic | `HapticFeedback.lightImpact()` on pointer-down (same as `SacButton` / `SacCard`) |
| Reduced motion | scale stays `1.0`; tap + haptic still run |

Two gesture modes (required — Club vs the rest):

- `listenOnly: false` (default) — `GestureDetector` with optional `onTap` (Support / Materials / Camporees / Monthly Reports).
- `listenOnly: true` — `Listener` only, **no** `onTap`. Child keeps its own gesture arena (Club address field).

```dart
/* target API */
class SacPressable extends StatefulWidget {
  const SacPressable({
    super.key,
    required this.child,
    this.onTap,
    this.enabled = true,
    this.listenOnly = false,
    this.semanticLabel,
    this.semanticButton = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;
  final bool listenOnly;
  final String? semanticLabel;
  final bool semanticButton;
}
```

When `listenOnly == true`, ignore `onTap` (assert in debug if both are set). Scale still follows pointer down/up/cancel.

When `enabled == false`, no scale, no haptic, no tap.

Export from `lib/core/widgets/sac_widgets.dart`.

Call-site mapping:

| Current | Replace with |
| --- | --- |
| `SupportPressable(...)` | `SacPressable(...)` same args (`onTap`, `enabled`, `semanticLabel`, `semanticButton`) |
| `MaterialsPressable(...)` | `SacPressable(onTap: ..., child: ...)` — drop `pressedScale` |
| `MonthlyReportPressable(...)` | `SacPressable(onTap: ..., child: ...)` — drop `pressedScale` / unused `borderRadius` |
| `camporees_list_view.dart` `_Pressable` | `SacPressable` — delete the private class |
| `club_view.dart` `_ClubPressable` | `SacPressable(listenOnly: true, enabled: editable, child: ...)` — delete the private class |

Delete `lib/features/materials/presentation/widgets/materials_pressable.dart` after both call sites move (`product_card.dart`, `order_card.dart`).

Delete `SupportPressable` class from `support_chrome.dart`. Keep `supportAppBar` / `SupportDestination`.

Do **not** rewrite `SacButton` or `SacCard` to wrap `SacPressable` in this plan (they already match the numbers).

## Repo conventions to follow

```dart
/* lib/core/widgets/sac_button.dart:404-420 — exemplar */
          onTapDown: ... HapticFeedback.lightImpact(); _setPressed(true);
          child: AnimatedScale(
            scale: (!reduce && _pressed) ? SacMotion.pressScale : 1,
            duration: SacMotion.press,
            curve: SacMotion.easeOut,
```

`SacCard` (post-004) is the same recipe. Copy it.

## Steps

1. Add `lib/core/widgets/sac_pressable.dart` with both gesture modes and the Target numbers.
2. Export it from `sac_widgets.dart`.
3. Swap the five call-site families listed above. Add imports. Delete the old classes / `materials_pressable.dart`.
4. `rg 'SupportPressable|MaterialsPressable|MonthlyReportPressable|_ClubPressable' lib` must be empty (except comments you did not add).
5. Optional tiny widget test next to `test/core/widgets/sac_card_test.dart`: press down → `AnimatedScale.scale == 0.97`; Reduced Motion → `1`. Skip if you would need a new harness file you cannot keep under 80 lines.

## Boundaries

- Do NOT change card/button visuals.
- Do NOT give Club's address field a competing `onTap` (`listenOnly: true` only).
- Do NOT keep `0.98` or `120ms` as overrides.
- Do NOT add packages.
- Do NOT migrate InkWells outside these five families.

## Verification

- **Mechanical**: `dart analyze` on `sac_pressable.dart`, `club_view.dart`, `support_chrome.dart`, `camporees_list_view.dart`, `monthly_report_motion.dart`, `product_card.dart`, `order_card.dart`. `rg` check. No `flutter build`.
- **Feel check**:
  - Support FAQ row, camporee card, materials product, monthly-report row, Club address (editable): hold → 97% in 140ms, ease-out, haptic on down. Release → 1.0. Same feel as a `SacCard`.
  - Club address: tap still opens the map picker (child gesture intact).
  - Reduce Motion: no scale; taps still work.
  - Spam taps: `AnimatedScale` retargets, no keyframe restart.
- **Done when**: one widget, one set of numbers; old pressable types gone; Club still listen-only.
