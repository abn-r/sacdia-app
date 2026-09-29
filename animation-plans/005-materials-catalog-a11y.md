# 005 — Raise Materiales chrome to 44pt hits without fat pills

- **Status**: DONE
- **Commit**: 3c97bd82
- **Severity**: HIGH
- **Category**: Accessibility
- **Estimated scope**: 4 files + tests

## Problem

Compact 28px pills (`SacFilterChip.minHeight`) plus a 40px Programa row and a 36px dense search made Materiales look fragile and miss Apple HIG / WCAG 44×44 targets. Quiet selected used `AppColors.primary` on `primary.alpha(0.10)` (color-only, weak contrast). Categoría caption was 11px `textTertiary`.

Do **not** reopen fat filled pills. Visual pill stays 28.

## Target

| Token | Value |
| --- | --- |
| Visual pill | `SacFilterChip.minHeight = 28` |
| Hit / row track | `SacFilterChip.hitExtent = 44`, `barHeight = hitExtent` |
| Quiet selected | bg `AppColors.primaryLight` (`#FDE8E6`), fg+border `AppColors.primaryDark` (`#D94A3B`) |
| Chip type | 13 / w700 (count 12) |
| Press | `SacMotion.press` 140ms, `easeOut` Cubic(0.23, 1, 0.32, 1), scale 0.97 via `SacPressable` |
| Color morph | `SacMotion.standard` 200ms `easeOut` on `AnimatedContainer` (state indication, not layout) |
| Search | minHeight 44, type 15, hint `textSecondary`, prefix slot 44 |
| Programa field | minHeight 44, type 15, chevron 18 `textSecondary` |
| Sheet rows | minHeight 44, type 17, tick 20 `primaryDark`, `Semantics(selected:)` |
| Categoría caption | 13 w600 `textSecondary`, `Semantics(header: true)` |

Layout for the chip (shrink-wrap width, tight 44 height — do **not** use `Align` under unbounded max or the chip fills the screen):

```dart
SizedBox(
  height: SacFilterChip.hitExtent,
  child: Center(
    widthFactor: 1,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minWidth: SacFilterChip.hitExtent),
      child: AnimatedContainer(
        constraints: const BoxConstraints(minHeight: SacFilterChip.minHeight),
        // …
      ),
    ),
  ),
);
```

## Repo conventions to follow

- Motion tokens only from `lib/core/animations/motion_tokens.dart`.
- Hits via `SacPressable` (press on pointer-down). Exemplar: `lib/core/widgets/sac_button.dart`.
- Quiet vs filled already on `SacFilterChipVariant`.

## Steps

Already applied in this pass:

1. `lib/core/widgets/sac_filter_chip.dart` — `hitExtent`, quiet contrast, 44 hit / 28 pill, `Semantics(selected:)`.
2. `lib/features/materials/presentation/widgets/materials_program_field.dart` — 44 field + sheet rows.
3. `lib/features/materials/presentation/views/catalog_view.dart` — search 44, caption 13 secondary + header semantics.
4. `lib/features/activities/presentation/views/activities_list_view.dart` — skeleton centered in 44 track.
5. Tests: chip hit vs pill, quiet `primaryLight`, program field ≥44, catalog search ≥44.

## Boundaries

- Do NOT densify `ProductCard` / `childAspectRatio: 0.72`.
- Do NOT set `SacFilterChip.minHeight` back to 44.
- Do NOT animate search typing or chip tap with layout (height/width). Color + press scale only.
- Do NOT use `ease-in`. Do NOT `scale(0)`.

## Verification

- **Mechanical**: `flutter test test/core/widgets/sac_filter_chip_test.dart test/features/materials/presentation/widgets/materials_program_field_test.dart test/features/materials/presentation/views/catalog_view_test.dart`
- **Feel check**: Materiales — pill still reads as the compact 28 capsule; extra 8px is empty hit, not a fatter fill. Quiet **Todas** is dark coral on blush, not coral-on-coral wash. Programa row and search match ~44. Sheet options are 44+ with a tick, not color-only. Rapid chip taps: `SacPressable` retargets; `AnimatedContainer` color does not jump from 0.
- Toggle reduce-motion: press scale off; color still changes.
- **Done when**: widget height 44, `AnimatedContainer` 28, quiet selected `primaryLight`/`primaryDark`.
