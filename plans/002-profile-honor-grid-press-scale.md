# 002 — Add press scale to profile honor grid items

- **Status**: TODO
- **Commit**: `11ee503`
- **Severity**: MEDIUM
- **Category**: Physicality & origin
- **Estimated scope**: 1 production file, ~40 lines; optional 1 widget test

## Problem

Profile honor badges are tappable but give no press feedback. The grid item wraps
content in a bare `GestureDetector`:

```dart
// lib/features/profile/presentation/widgets/profile_honors_section.dart:349 — current
return GestureDetector(
  onTap: () => context.push(
    profileHonorDestinationPath(userHonor),
    extra: profileHonorRouteExtra(userHonor),
  ),
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
```

Taps feel dead until the route transition starts. AUDIT.md press target:
`transform: scale(0.97)` with ~160ms ease-out; keep subtle (0.95–0.98).

## Target

Convert `_HonorGridItem` to a `StatefulWidget` and mirror the repo's pressable
pattern:

```dart
// target — inside _HonorGridItemState.build
final reduce = SacMotion.reduceMotionOf(context);
return GestureDetector(
  behavior: HitTestBehavior.opaque,
  onTapDown: (_) => _setPressed(true),
  onTapUp: (_) => _setPressed(false),
  onTapCancel: () => _setPressed(false),
  onTap: () => context.push(
    profileHonorDestinationPath(widget.userHonor),
    extra: profileHonorRouteExtra(widget.userHonor),
  ),
  child: AnimatedScale(
    scale: (!reduce && _pressed) ? 0.97 : 1,
    duration: SacMotion.press, // 140ms
    curve: Curves.easeOut,
    child: Column(
      // unchanged children using widget.userHonor / widget.categoryColor
    ),
  ),
);
```

Exact values:

| Token / value | Source |
|---|---|
| `scale` pressed | `0.97` |
| `duration` | `SacMotion.press` = `Duration(milliseconds: 140)` |
| `curve` | `Curves.easeOut` (repo pressable convention) |
| Reduced Motion | no scale change (`scale: 1` when `SacMotion.reduceMotionOf(context)`) |

## Repo conventions to follow

- Motion tokens: `lib/core/animations/motion_tokens.dart` (`SacMotion.press`, `reduceMotionOf`).
- Exemplar: `lib/features/materials/presentation/widgets/materials_pressable.dart:21-45` — `AnimatedScale` + `onTapDown/Up/Cancel` + reduce-motion gate.
- Do **not** import `MaterialsPressable` into Profile (wrong feature boundary). Copy the pattern locally into `_HonorGridItem`.

## Steps

1. In `lib/features/profile/presentation/widgets/profile_honors_section.dart`, add:
   `import 'package:sacdia_app/core/animations/motion_tokens.dart';`
2. Change `_HonorGridItem` from `StatelessWidget` to `StatefulWidget` with private
   `_HonorGridItemState`.
3. In state: `bool _pressed = false;` and `_setPressed(bool)` that no-ops when
   unchanged (same as MaterialsPressable).
4. Replace the bare `GestureDetector` with the target snippet above. Keep navigation
   exactly as today (`profileHonorDestinationPath` + `profileHonorRouteExtra`).
5. Leave badge image, status chip, and label markup unchanged.

## Boundaries

- Do NOT change navigation destinations or Honor seed extras.
- Do NOT add dependencies.
- Do NOT extract a new shared pressable into `core/` in this plan.
- Do NOT change MasterHonorHistorySection or category headers.
- If `_HonorGridItem` structure drifted from this stamp, STOP and report.

## Verification

- **Mechanical**:
  - `flutter test test/features/profile/presentation/utils/profile_honor_navigation_test.dart`
  - `dart analyze lib/features/profile/presentation/widgets/profile_honors_section.dart`
- **Feel check**:
  - Open Profile → Especialidades. Press-and-hold a badge: scales to ~0.97 then releases to 1.
  - Tap through: navigation still works (detail / requirements / evidence).
  - Enable Reduce Motion (app accessibility setting or system): press scale must not run; tap still navigates.
  - Slow the animation in Flutter DevTools (time dilation 5–10×) and confirm duration ~140ms, ease-out (fast start).
- **Done when**: press scale present at 0.97 / `SacMotion.press`, gated by reduce-motion, navigation unchanged.
