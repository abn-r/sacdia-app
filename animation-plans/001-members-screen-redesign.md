# 001 — Redesign Members screen tabs, press, and tab motion

- **Status**: DONE
- **Commit**: `3c97bd82` (working tree also has uncommitted third tab «No inscritos» in `members_view.dart`)
- **Severity**: HIGH
- **Category**: Purpose & frequency + Physicality & origin + Missed opportunities
- **Estimated scope**: 4 files (1 new widget, 2 view edits, 1 card wrap)

## Problem

Operational roster screen. Directors hit it tens of times per day. Current chrome fights that frequency and the new third tab.

**1. Three equal-width Material tabs crush labels.** Screenshot: «Miembros» / «Solicitudes» / «No inscritos» share one track. `TabAlignment.fill` forces identical slots. The year-start job (unenrolled) looks like a leftover, not a mode.

```dart
/* sacdia-app/lib/features/members/presentation/views/members_view.dart:169-229 — current */
child: TabBar(
  controller: _tabController,
  indicator: BoxDecoration(
    color: c.surface,
    borderRadius: BorderRadius.circular(10),
    boxShadow: [
      BoxShadow(
        color: context.sac.shadow,
        blurRadius: 4,
        offset: const Offset(0, 2),
      ),
    ],
  ),
  indicatorSize: TabBarIndicatorSize.tab,
  tabAlignment: TabAlignment.fill,
  // ...
  labelStyle: TextStyle(
    fontSize: showContinuationsTab ? 12 : 13,
    fontWeight: FontWeight.w600,
  ),
```

**2. Tab content uses default `TabBarView` page-slide.** Flutter `kTabScrollDuration` is **300ms** with `Curves.ease` (not ease-out). Tens/day. Horizontal swipe also fights the vertical member list.

```dart
/* members_view.dart:241-256 — current */
return TabBarView(
  controller: _tabController,
  children: [
    _MembersTab(...),
    _JoinRequestsTab(...),
    if (showContinuationsTab) const AnnualContinuationsBody(),
  ],
);
```

`TabController` is constructed **without** `animationDuration`:

```dart
/* members_view.dart:47-48 — current */
_tabController = TabController(length: canContinue ? 3 : 2, vsync: this);
```

**3. Member rows have Material splash, no press scale.** `SacPressable` already exists (`scale: 0.97`, `SacMotion.press` 140ms, `SacMotion.easeOut`). Cards ignore it.

```dart
/* sacdia-app/lib/features/members/presentation/widgets/member_card.dart:32-38 — current */
return Material(
  color: c.surface,
  borderRadius: BorderRadius.circular(14),
  child: InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Container(
```

**4. Dead stagger wrappers on join-request rows.** `StaggeredListItem` defaults `animate: false`, so this is cost with no motion. Dense lists must stay still.

```dart
/* members_view.dart:502-515 — current */
return StaggeredListItem(
  index: index,
  initialDelay: const Duration(milliseconds: 30),
  child: JoinRequestCard(
```

**5. «No inscritos» has no count.** Solicitudes gets `_PendingBadge`. Unenrolled is the D02 job and looks empty until opened.

Do **not** treat age-9 AV→CQ as a UI bug. Backend `TYPE_JUMP` Aventureros `minAge: 10` at `targetYear.start_date`. Blocked copy stays policy text. This plan does not change eligibility.

## Target

Crisp operational switcher. Indicator slides and **clips** a duplicate active label row (Emil tab color trick). Content **fades**, no page-slide. Press scale on rows. Badge on unenrolled.

### Mode switcher (replace `TabBar`)

New widget `MembersModeSwitcher` in
`sacdia-app/lib/features/members/presentation/widgets/members_mode_switcher.dart`.

Track: `c.surfaceVariant`, radius 12, padding 4. Height 44 (keep July 2026 compact spec).

**Inactive row:** all labels `c.textSecondary`, weight 600, size **13** (stop shrinking to 12). Badges sit after Solicitudes / No inscritos.

**Active overlay:** a `ClipRRect` radius 10, fill `c.surface`, shadow `c.shadow` blur 4 offset (0, 2). Inside it, a **second** full-width label row with `c.text` / weight 700, offset by `-indicatorLeft` so the clipped window shows the matching label. Sliding the clip (not recoloring each `Text`) is the color transition.

Motion of the clip:

- duration: **180ms** (`Duration(milliseconds: 180)` — between press 140 and standard 200)
- curve: `SacMotion.easeOut` = `Cubic(0.23, 1, 0.32, 1)`
- animate **`transform: Translate` of the clip window** (or `AnimatedAlign` + measured widths), **not** `width`/`left` layout animation
- measure each tab with `GlobalKey` / `context.size` after first layout; indicator width = that tab’s width
- `prefers-reduced-motion` / `SacMotion.reduceMotionOf`: duration **0ms**, snap clip, keep opacity of content fade at `SacMotion.reducedFade` (160ms) only

Press on a segment: wrap each hit target in `SacPressable` (`pressScale` 0.97, `press` 140ms, `easeOut`). No Material splash.

Hit targets ≥ 44px height. Three segments; widths **intrinsic** (label + badge + 16px horizontal padding), not equal fill. If overflow, allow horizontal scroll of the switcher only (`SingleChildScrollView` + `NeverScrollableScrollPhysics` on parent list). Do not ellipsize «No inscritos».

Badge for continuations: count of items in `AnnualContinuationsState.items` (or enrollable-only if cheaper). Same visual as `_PendingBadge` (`AppColors.error`, 10px white w700). If count 0, no badge.

### Content (replace `TabBarView`)

`IndexedStack` (keeps tab state) + `AnimatedOpacity` / `FadeTransition` on the **visible** child only:

- duration **160ms**
- curve `SacMotion.easeOut`
- no `SlideTransition`, no `PageView`
- no horizontal swipe between modes
- reduced motion: opacity only, 160ms (`SacMotion.reducedFade`)

Keep `TabController` **or** drop it for `int _mode`. Prefer `int _mode` (0 members, 1 requests, 2 continuations) so nothing inherits `kTabScrollDuration`. If `TabController` stays, set:

```dart
TabController(
  length: length,
  vsync: this,
  animationDuration: Duration.zero, // indicator owned by MembersModeSwitcher
)
```

and **do not** attach `TabBarView`.

### Member cards

Replace `InkWell` with `SacPressable` wrapping the same bordered container. `listenOnly: false`, `onTap: onTap`. Drop Material splash. Radius 14 unchanged. Padding stays 14 (do not reopen the July compact-height debate unless a later plan).

```dart
return SacPressable(
  onTap: onTap,
  enabled: onTap != null,
  child: Container(
    decoration: BoxDecoration(
      color: c.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: c.border),
    ),
    padding: const EdgeInsets.all(14),
    child: Row( /* existing children, unchanged */ ),
  ),
);
```

`SacPressable` already: `AnimatedScale` scale `SacMotion.pressScale` (0.97), duration `SacMotion.press` (140ms), curve `SacMotion.easeOut`, haptic light, skips scale when `SacMotion.reduceMotionOf`.

Apply the same wrap to `JoinRequestCard` and `_ContinuationItem` if they still use `InkWell`/`Material` splash after this change. If `JoinRequestCard` already uses `SacPressable`, leave it.

### Stagger

Remove `StaggeredListItem` around `JoinRequestCard`. Do not set `animate: true` on the members list.

### Tokens — do not invent new curves

Use only `sacdia-app/lib/core/animations/motion_tokens.dart`:

```dart
static const Curve easeOut = Cubic(0.23, 1, 0.32, 1);
static const Duration press = Duration(milliseconds: 140);
static const Duration reducedFade = Duration(milliseconds: 160);
static const Duration standard = Duration(milliseconds: 200);
static const double pressScale = 0.97;
```

Add **one** named duration if 180ms is used for the clip:

```dart
static const Duration switcher = Duration(milliseconds: 180);
```

Do not add bounce. Do not use `ease-in`. Do not `scale` the indicator from 0. Start clip from previous tab’s rect (always visible shape).

## Repo conventions to follow

- Motion tokens: `sacdia-app/lib/core/animations/motion_tokens.dart`
- Press exemplar: `sacdia-app/lib/core/widgets/sac_pressable.dart` (entire file) and `SacFilterChip` which already wraps with `SacPressable` + `AnimatedContainer` `SacMotion.standard` / `SacMotion.easeOut`
- Stagger policy already documented on `StaggeredListItem`: dense lists stay still (`animate: false`)
- Members compact height 44dp from `docs/plans/2026-07-17-members-compact-tabs-cards-design.md` — keep height, change indicator behavior
- i18n keys already exist: `members.view.members_tab`, `requests_tab`, `continuations_tab`

## Steps

1. **`motion_tokens.dart`**: add `static const Duration switcher = Duration(milliseconds: 180);` next to `standard`. No other token changes.

2. **Create** `sacdia-app/lib/features/members/presentation/widgets/members_mode_switcher.dart` implementing `MembersModeSwitcher` as specified in Target. Constructor:

```dart
class MembersModeSwitcher extends StatelessWidget {
  const MembersModeSwitcher({
    required this.index,
    required this.onChanged,
    required this.showContinuations,
    required this.pendingRequests,
    required this.pendingContinuations,
  });
  final int index;
  final ValueChanged<int> onChanged;
  final bool showContinuations;
  final int pendingRequests;
  final int pendingContinuations;
}
```

3. **`members_view.dart`**:
   - Replace `TabBar` widget with `MembersModeSwitcher`.
   - Replace `TabBarView` with `IndexedStack` + fade as specified.
   - Drop `TabController` / `SingleTickerProviderStateMixin` unless still needed; use `int _mode`.
   - `_syncTabCount` becomes: if `!canContinue && _mode == 2` then `_mode = 0`.
   - Refresh app-bar: `_mode == 2` → invalidate continuations; else members refresh (same as current).
   - Watch `annualContinuationsNotifierProvider` **only** when `showContinuationsTab` to feed `pendingContinuations` (items length). Accept the extra GET when a director opens Miembros — needed for the badge.
   - Remove `StaggeredListItem` import usage in `_JoinRequestsTab`.
   - Keep permission gate: third mode only if `club_members:approve`.

4. **`member_card.dart`**: swap `Material`+`InkWell` for `SacPressable` as in Target. Preserve avatar, name, role, class chip, enrolled badge, assign-role control.

5. **`annual_continuations_view.dart` `_ContinuationItem`**: if it uses `InkWell`, wrap with `SacPressable` the same way. Keep checkbox semantics.

6. **Tests**: extend `test/features/members/annual_membership_flow_test.dart` OR add `members_mode_switcher_test.dart`:
   - 3 labels visible when `showContinuations: true`
   - tap «No inscritos» calls `onChanged(2)`
   - badge shows `pendingContinuations` when > 0
   - existing `AnnualContinuationsView` test still finds «Luis Pérez Soto» / submit button

## Boundaries

- Do NOT change `NextClassResolver`, year-cut, or `TYPE_JUMP` ages (10 / 16).
- Do NOT change annual-continuations API, DTO, or blocked-reason copy.
- Do NOT restyle dashboard, login, honors, or camporee tabs.
- Do NOT enable list stagger (`animate: true`).
- Do NOT add animation packages.
- Do NOT use `TabAlignment.fill` or shrink font to 12 to fit three labels.
- Do NOT auto-land on «No inscritos» as default tab.
- If files drifted from commit `3c97bd82` + the uncommitted tab, STOP and report; do not invent a fourth mode.

## Verification

- **Mechanical**: from `sacdia-app/`:
  ```sh
  dart analyze lib/features/members/presentation/views/members_view.dart \
    lib/features/members/presentation/views/annual_continuations_view.dart \
    lib/features/members/presentation/widgets/member_card.dart \
    lib/features/members/presentation/widgets/members_mode_switcher.dart
  flutter test test/features/members/annual_membership_flow_test.dart
  ```
  Analyze: no issues. Tests: all passed.

- **Feel check** (iOS simulator, director with `club_members:approve`):
  - Three labels fully readable; pill width follows the selected label, not 33%.
  - Spam-tapping Miembros ↔ Solicitudes ↔ No inscritos: clip **retargets** from current position (no restart from tab 0). Duration feels like a tap, not a page turn (~180ms).
  - Slow-mo (time dilation 5×): active text color is a moving window, not two overlapping label colors.
  - Vertical fling on the member list never changes mode.
  - Press a member row: scale 0.97 then release 140ms ease-out. No grey Material splash.
  - Reduce Motion (iOS Settings → Accessibility): clip snaps; content still fades; no translate of the list.
  - Age-9 last-AV candidate in No inscritos: stays **blocked** with catalog/age/section copy, not enrolled.

- **Done when**: switcher clip + fade content + press on cards ship; eligibility unchanged; tests green.
