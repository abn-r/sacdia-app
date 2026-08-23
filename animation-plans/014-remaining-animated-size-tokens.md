# 014 — Remaining AnimatedSize expanders: tokens + Reduced Motion

- **Status**: DONE
- **Commit**: `aee5edf0`
- **Severity**: MEDIUM
- **Category**: Cohesion / accessibility
- **Estimated scope**: 6 files, ~20–40 lines

## Problem

Plan 011 fixed the activities date strip. FAQ and units already use `SacMotion.standard` + RM `Duration.zero`. Six leftover expanders still use raw Material numbers and ignore Reduced Motion.

```dart
/* lib/features/activities/presentation/views/create_activity_view.dart:490-492 — current */
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
```

Same 250ms / `Curves.easeInOut` pair (no RM):

| File | Lines |
| --- | --- |
| `create_activity_view.dart` | ~490, ~610 (joint sections + virtual fields) |
| `edit_activity_view.dart` | ~543, ~662 (same two expanders) |

```dart
/* lib/features/post_registration/presentation/views/allergies_selection_view.dart:949-951 — current */
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
```

Same 200ms / `Curves.easeOut` (no RM): `medicines_selection_view.dart` ~911, `diseases_selection_view.dart` ~914.

```dart
/* lib/features/finances/presentation/widgets/range_bottom_sheet.dart:112-114 — current */
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: _selectedPreset == DateRangePreset.custom
```

No curve → Flutter default `Curves.linear`. No RM.

Morph-on-screen → `easeInOut`. Duration already in the 200ms band; snap the token. RM snaps height.

## Target

Every leftover `AnimatedSize` in the table:

| Property | Value |
| --- | --- |
| Duration (motion allowed) | `SacMotion.standard` (`200ms`) |
| Curve | `SacMotion.easeInOut` = `Cubic(0.77, 0, 0.175, 1)` |
| Reduced motion | `Duration.zero` |

```dart
/* target */
          AnimatedSize(
            duration: SacMotion.reduceMotionOf(context)
                ? Duration.zero
                : SacMotion.standard,
            curve: SacMotion.easeInOut,
            child: /* unchanged */
```

Keep children, alignment, and chrome. Only duration + curve (+ add `curve` on the finances sheet).

Import `motion_tokens.dart` where missing:

- create/edit: `package:sacdia_app/core/animations/motion_tokens.dart` (create already has `page_transitions.dart`)
- post-registration three: same package import next to other `sacdia_app/core/` imports
- finances sheet: `../../../../core/animations/motion_tokens.dart` next to the other `../../../../core/` imports

## Repo conventions to follow

- Plan 011 date strip (already shipped): same three values.
- FAQ / units already correct — **do not edit** them (they use `easeOut` on purpose for accordion reveal; leave them).
- Tokens: `lib/core/animations/motion_tokens.dart`. Do not invent durations.

## Steps

1. Patch the six files. Two call sites each in create + edit. One each in the other four.
2. `rg 'AnimatedSize' lib` — every live call uses `SacMotion.standard` and an RM `Duration.zero` branch (FAQ/units already do).

## Boundaries

- Do NOT restyle form fields, chips, or the range sheet chrome.
- Do NOT edit `faq_item_card.dart`, `unit_detail_view.dart`, or `activities_list_view.dart`.
- Do NOT replace `AnimatedSize` with fade/slide.
- Do NOT add packages.
- If a listed `AnimatedSize` is gone, STOP and report that file.

## Verification

- **Mechanical**: `dart analyze` on the six files. No `flutter build`.
- **Feel check**:
  - Crear/editar actividad: toggle conjunta / virtual. Height eases 200ms, no linear, no bounce.
  - Finanzas range → Personalizado: custom fields expand 200ms `easeInOut`.
  - Alergias / medicinas / enfermedades: extra block expands the same way.
  - Reduce Motion on: all six snap. No height travel.
- **Done when**: no raw `250` / `Curves.easeInOut` / `Curves.easeOut` on these `AnimatedSize`s; all leftover expanders read `SacMotion`.
