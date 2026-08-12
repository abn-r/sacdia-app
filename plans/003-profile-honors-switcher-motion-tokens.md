# 003 — Align profile honors AnimatedSwitcher to SacMotion + Reduced Motion

- **Status**: TODO
- **Commit**: `11ee503`
- **Severity**: MEDIUM
- **Category**: Cohesion & tokens / Accessibility
- **Estimated scope**: 1 production file, ~10 lines

## Problem

`ProfileHonorsSection` crossfades skeleton → data with a hard-coded 300ms duration
and no Reduced Motion branch:

```dart
// lib/features/profile/presentation/widgets/profile_honors_section.dart:110-112 — current
return AnimatedSwitcher(
  duration: const Duration(milliseconds: 300),
  child: userHonorsAsync.when(
```

Problems:

1. Bypasses `SacMotion` tokens (`standard` = 200ms).
2. Ignores `MediaQuery.disableAnimations` / app reduce-motion (already merged in
   accessibility provider).
3. 300ms sits at the top of the UI budget; skeleton→content should feel snappier.

## Target

```dart
// target — ProfileHonorsSection.build
final reduce = SacMotion.reduceMotionOf(context);

return AnimatedSwitcher(
  duration: reduce ? Duration.zero : SacMotion.standard, // 0 or 200ms
  switchInCurve: SacMotion.easeOut,   // Cubic(0.23, 1, 0.32, 1)
  switchOutCurve: SacMotion.easeOut,
  child: userHonorsAsync.when(
    // existing loading / error / data branches unchanged
```

Exact values:

| Property | Normal | Reduced Motion |
|---|---|---|
| `duration` | `SacMotion.standard` (200ms) | `Duration.zero` |
| `switchInCurve` / `switchOutCurve` | `SacMotion.easeOut` | unused (duration 0) |

Keep existing `ValueKey`s (`honors-skeleton`, `honors-error`, `honors-data`).

## Repo conventions to follow

- Tokens: `lib/core/animations/motion_tokens.dart`.
- Exemplar for reduce → `Duration.zero`:
  `lib/features/units/presentation/views/unit_detail_view.dart:459`
  (`duration: reduce ? Duration.zero : SacMotion.standard`).
- Ease-out for enter/exit UI: AUDIT.md + `SacMotion.easeOut`.

## Steps

1. Ensure `import 'package:sacdia_app/core/animations/motion_tokens.dart';` exists
   (may already be added by plan 002 — reuse, do not duplicate).
2. At the start of `ProfileHonorsSection.build`, read
   `final reduce = SacMotion.reduceMotionOf(context);`.
3. Replace `duration: const Duration(milliseconds: 300)` with the target values.
4. Add `switchInCurve` / `switchOutCurve` as above.
5. Do not alter `when(` branches, skeleton, or MasterHonorHistorySection placement.

## Boundaries

- Do NOT change provider wiring or skeleton layout.
- Do NOT introduce FadeThrough / custom transitions beyond `AnimatedSwitcher` props.
- Do NOT touch honor detail motion.
- If another plan already added the `SacMotion` import, only edit the switcher.

## Verification

- **Mechanical**:
  - `dart analyze lib/features/profile/presentation/widgets/profile_honors_section.dart`
- **Feel check**:
  - Cold Profile load: skeleton → badges crossfade in ~200ms, ease-out (starts quick).
  - Reduce Motion on: swap is instant (no perceptible fade).
  - Error and empty states still switch with the same keys.
- **Done when**: no hard-coded 300ms; uses `SacMotion.standard` / `easeOut`; reduce-motion zeros duration.
