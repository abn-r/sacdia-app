# 004 — Redesign Materiales catalog chrome (program switcher, quiet categories, keep-grid fade)

- **Status**: DONE
- **Commit**: `3c97bd82` (working tree also has compact `SacFilterChip` minHeight 28)
- **Severity**: HIGH
- **Category**: Cohesion + Purpose & frequency + Missed opportunities
- **Estimated scope**: 5 files (1 new widget, catalog view, chip variant, 2 tests)

## Problem

Browse-catalog chrome. Directors/members hit program + category filters tens of times per shopping session. After compacting pills to 28px, two unlabeled `SacFilterChip` rows still share the same filled-primary selected treatment. Screenshot: **Todos** and **Todas** both coral — looks like one broken control. Search stays a 48px icon slot. Changing a filter keys a new `catalogProvider(CatalogQuery)` family member, which starts `AsyncLoading` and **teleports** the grid to a 4-card skeleton.

Do **not** reopen `SacFilterChip.minHeight = 28`. Do **not** densify `ProductCard` / `childAspectRatio: 0.72` (finding 5, not selected).

**1. Program and category are the same widget.** Programa is a 4-value **mode** (Todos + club types). Categoría is a scrolling **facet**. Both use filled primary.

```dart
/* sacdia-app/lib/features/materials/presentation/views/catalog_view.dart:161-226 — current */
return SizedBox(
  height: SacFilterChip.barHeight,
  child: ListView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.fromLTRB(16, 0, 28, 0),
    children: [
      Padding(
        padding: const EdgeInsets.only(right: 8),
        child: SacFilterChip(
          label: 'materials.catalog.filter_all'.tr(),
          selected: _selectedProgramaId == null,
          onTap: () => setState(() => _selectedProgramaId = null),
        ),
      ),
      ...programas.map(
        (p) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: SacFilterChip(
            label: p.label,
            selected: _selectedProgramaId == p.id,
            onTap: () => setState(() => _selectedProgramaId = p.id),
          ),
        ),
      ),
    ],
  ),
);
```

Category row immediately below is the same chip, `filter_all_categories` = «Todas».

**2. Grid teleports to skeleton on every query change.** Family `build` always fetches page 1; a new key has no previous `AsyncData`.

```dart
/* sacdia-app/lib/features/materials/presentation/providers/catalog_provider.dart:69-76 — current */
class CatalogNotifier
    extends AutoDisposeFamilyAsyncNotifier<CatalogState, CatalogQuery> {
  static const _pageSize = 20;

  @override
  Future<CatalogState> build(CatalogQuery query) async {
    return _fetchPage(query: query, page: 1, existing: const []);
  }
```

```dart
/* catalog_view.dart:230-236 — current */
Expanded(
  child: catalogAsync.when(
    loading: () => const _CatalogSkeleton(),
    error: (error, _) => _ErrorState(...),
    data: (state) { ... GridView.builder ... },
  ),
),
```

**3. Search is taller than the compact chips.** `FixedInputIconSlot.constraints` is 48×48. Theme input + `contentPadding` vertical 10 keep the field chunky.

```dart
/* catalog_view.dart:123-154 — current */
Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  child: TextField(
    ...
    prefixIconConstraints: FixedInputIconSlot.constraints,
    contentPadding: const EdgeInsets.symmetric(vertical: 10),
  ),
),
```

`SacFilterChip` `AnimatedContainer` still animates every decoration field (`transition: all` equivalent). Do **not** restyle the chip globally in this plan. Programa leaves the chip. Categoría uses a **quiet** variant (no fill primary).

## Target

Crisp browse chrome. Program = compact clip switcher (Emil duplicate-row + clip). Category = quiet outline pills. Search matches 28px density. Grid keeps last items while the new query loads, then **fades** 160ms. No stagger. No page-slide.

### Program switcher (replace program `SacFilterChip` row)

New widget `MaterialsProgramSwitcher` in
`sacdia-app/lib/features/materials/presentation/widgets/materials_program_switcher.dart`.

Copy the clip machinery from `members_mode_switcher.dart` (measure `GlobalKey`s, lerp rect, `Transform.translate` of a `ClipRRect` window over a duplicate **active** label row). Compact numbers — not the 44px members track:

- Outer height: **32**
- Track padding: **2** (slot height **28**)
- Track fill: `c.surfaceVariant`, radius **10**
- Clip window: radius **8**, fill `c.surface`, shadow `c.shadow` blur 4 offset `(0, 2)`
- Inactive labels: `c.textSecondary`, w600, size **12**
- Active labels (inside clip): `c.text`, w700, size **12**
- Horizontal slot padding: **12**
- No badges

Motion of the clip (same tokens as members):

- duration: `SacMotion.switcher` = **180ms**
- curve: `SacMotion.easeOut` = `Cubic(0.23, 1, 0.32, 1)`
- animate **`Transform.translate` of the clip window**, **not** `width` / `left` layout
- `SacMotion.reduceMotionOf`: duration **0ms**, snap clip
- Press: each segment wrapped in `SacPressable` (`pressScale` 0.97, `press` 140ms)
- Spam-tap must **retarget** from current rect (`_from = _currentRect()` then `_play()`), never restart from index 0
- Never `scale(0)` the indicator. Clip always has a visible width after first measure

API — labels from parent (no i18n inside the widget):

```dart
class MaterialsProgramSwitcher extends StatefulWidget {
  const MaterialsProgramSwitcher({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
}
```

In `catalog_view.dart`, index `0` = Todos (`_selectedProgramaId = null`). Index `i > 0` = `programas[i - 1].id`. If `programas.isEmpty`, hide the switcher (same as today). Horizontal padding 16 around the switcher. Allow horizontal scroll if labels overflow. Do not ellipsize.

Do **not** extract a shared core switcher. Do **not** change `MembersModeSwitcher` height or API.

### Category chips (quiet)

Keep the horizontal `ListView` at `SacFilterChip.barHeight` (28). Add optional variant, default **filled** so Recursos / Actividades / Logros stay coral:

```dart
enum SacFilterChipVariant { filled, quiet }
```

Quiet **selected**: background `AppColors.primary.withValues(alpha: 0.10)`, foreground `AppColors.primary`, border `AppColors.primary`. Quiet **unselected**: same as filled unselected (`c.surface`, `c.textSecondary`, `c.border`). Height / padding / font stay 28 / 12+4 / 12. Still `SacPressable`.

Category row uses `variant: SacFilterChipVariant.quiet`. «Todas» stays the first chip. No axis caption.

### Search (this screen only)

Do **not** change `FixedInputIconSlot.constraints` (48). Catalog search only:

- `isDense: true`
- `prefixIconConstraints: BoxConstraints.tightFor(width: 36, height: 36)`
- `FixedInputIconSlot` `iconSize: 18`
- `contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)`
- Keep 400ms debounce

### Grid keep-last + fade

Keep `CatalogNotifier` fetch logic. In `_CatalogViewState`:

- Field `CatalogState? _lastCatalog`
- `ref.listen(catalogProvider(_query), …)` stores `next.valueOrNull` into `_lastCatalog` when non-null
- Display: `final fresh = catalogAsync.valueOrNull`
- `final displayed = fresh ?? (catalogAsync.isLoading ? _lastCatalog : null)`
- First visit (`displayed == null` && loading) → existing `_CatalogSkeleton`
- Current query error (`hasError && fresh == null && !isLoading`) → existing `_ErrorState` (do not keep stale on error)
- Else if `displayed.items.isEmpty` → existing empty / error-message branches
- Else: `AnimatedSwitcher`
  - duration `SacMotion.reducedFade` (**160ms**)
  - `switchInCurve` / `switchOutCurve`: `SacMotion.easeOut`
  - `transitionBuilder`: `FadeTransition(opacity: animation, child: child)` only — **no** `SlideTransition`, **no** `ScaleTransition`
  - child key: identity of **displayed items** (e.g. `ValueKey(displayed.items.map((i) => i.id).join(','))`), **not** the query. Loading with stale items must not fade to itself
- Reduced motion: keep the 160ms **opacity** fade; no translate/scale (there should be none)
- Do **not** wrap cards in `StaggeredListItem`. Do **not** dim the stale grid (`opacity: 0.7`) while loading

## Repo conventions to follow

- Motion tokens: `sacdia-app/lib/core/animations/motion_tokens.dart` — `easeOut`, `switcher` 180ms, `reducedFade` 160ms, `press` 140ms, `pressScale` 0.97. Do not add curves.
- Clip exemplar: `sacdia-app/lib/features/members/presentation/widgets/members_mode_switcher.dart` entire `build` + `_measure` / `_retarget` / `_play`
- Press exemplar: `SacPressable`
- i18n already exists: `materials.catalog.filter_all`, `filter_all_categories`, `search_hint`
- Chip height settled: `SacFilterChip.minHeight = 28` / `barHeight = 28`

## Steps

1. **`sac_filter_chip.dart`**: add `SacFilterChipVariant` (default `filled`). Quiet selected colors as in Target. Do not change minHeight, padding, or filled appearance.

2. **Create** `materials_program_switcher.dart` as specified. Rebuild keys when `labels.length` changes; snap-measure on label change; retarget on `index` change.

3. **`catalog_view.dart`**:
   - Compact search as specified.
   - Replace program chip `ListView` with `MaterialsProgramSwitcher`.
   - Category chips: `variant: SacFilterChipVariant.quiet`.
   - Keep-last + `AnimatedSwitcher` fade as specified. Extract a private `_CatalogGrid` if it keeps `build` readable. Preserve load-more cell.

4. **Tests**:
   - `test/features/materials/presentation/widgets/materials_program_switcher_test.dart`: shows all labels; tap second label calls `onChanged(1)`; height is 32.
   - `test/core/widgets/sac_filter_chip_test.dart`: quiet selected fill is **not** `AppColors.primary`.
   - `test/features/materials/presentation/views/catalog_view_test.dart`: with overridden `programsProvider` / `categoriesProvider` / `catalogProvider`, first frame shows a product title; after tapping a program with a delayed second query, the previous title is still on screen before the delay completes (no skeleton).

## Boundaries

- Do NOT change `SacFilterChip.minHeight` / `barHeight`.
- Do NOT change `ProductCard`, grid `childAspectRatio`, or product detail.
- Do NOT change `MembersModeSwitcher` or members tests.
- Do NOT change `FixedInputIconSlot.constraints`.
- Do NOT enable list/grid stagger.
- Do NOT add animation packages or new motion tokens.
- Do NOT use `ease-in`, `scale(0)`, or animate `width`/`left` of the clip.
- Do NOT restyle Recursos / Actividades / Logros chips (they keep filled).
- If `catalog_view.dart` drifted from the compact-chip + family-provider shape above, STOP and report.

## Verification

- **Mechanical**: from `sacdia-app/`:
  ```sh
  dart analyze lib/features/materials/presentation/views/catalog_view.dart \
    lib/features/materials/presentation/widgets/materials_program_switcher.dart \
    lib/core/widgets/sac_filter_chip.dart
  flutter test test/features/materials/presentation/widgets/materials_program_switcher_test.dart \
    test/core/widgets/sac_filter_chip_test.dart \
    test/features/materials/presentation/views/catalog_view_test.dart
  ```
  Analyze: no issues. Tests: all passed.

- **Feel check** (iOS simulator, Materiales):
  - Program track is one compact segmented control; only **one** coral/white filled control on screen (none, if program uses surface clip). Category «Todas» is tinted outline, not a second filled pill.
  - Spam-tap Todos ↔ Aventureros ↔ Conquistadores: clip retargets; ~180ms; not a page turn.
  - Slow-mo 5×: active label color is a moving window, not two overlapping fills.
  - Tap a category: grid does **not** flash 4 grey skeletons if a previous page was shown; new cards fade in 160ms.
  - Reduce Motion: clip snaps; grid still fades opacity.
  - Search field is visually closer to chip height than to the old 48px control.
  - Product cards unchanged (tall wash + price).

- **Done when**: program clip + quiet categories + compact search + keep-grid fade ship; chip height 28 unchanged; tests green.
