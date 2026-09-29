# 002 — Densify Members roster cards; clip list under filters

- **Status**: DONE
- **Commit**: `3c97bd82` (working tree already has 001 Members switcher uncommitted)
- **Severity**: HIGH
- **Category**: Purpose & frequency + Missed opportunities (layout density, not new motion)
- **Estimated scope**: 3 files (`member_card.dart`, `members_view.dart`, `member_card_test.dart`)

## Problem

Directors scan this roster tens of times per day. Current `MemberCard` is a three-row dashboard in a 48px-avatar tile. Class name is already in `MemberClassGroupHeader`. Enrollment badge `Inscrito` repeats on every enrolled row. Filter chips have no opaque bar, so the list paints through the gaps (screenshot: ghosted «Compañero / Inscrito» under Clase / Cargo / Estado).

```dart
/* sacdia-app/lib/features/members/presentation/widgets/member_card.dart:36-43 — current */
child: Container(
  decoration: BoxDecoration(
    color: c.surface,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: c.border),
  ),
  padding: const EdgeInsets.all(14),
```

Avatar is 48×48 with 2px border (`member_card.dart:176-187`). Name, then a full role row with label icon, then class **name** + enrolled badge (`member_card.dart:55-144`). Assign control is a 36×36 filled pink square (`member_card.dart:234-251`).

List gap is 10px under every card (`members_view.dart:296-297`). Filter bar sits in a `Column` with no background (`members_view.dart:209-215`); chip row is transparent between pills (`members_filter_bar.dart:89-91`).

Press motion from 001 is already correct: `SacPressable` + `SacMotion.press` 140ms + `SacMotion.easeOut` Cubic(0.23, 1, 0.32, 1) + `pressScale` 0.97. Do not add list stagger (tens/day).

## Target

**Card = two lines, 36px avatar, no duplicate class label, enrolled badge only when not enrolled.**

```dart
/* target — member_card.dart */
padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
borderRadius: BorderRadius.circular(12),
// avatar inner 36×36, border width 1.5, memCache 72
// name: 15 w600 maxLines 1
// meta row: 16px class logo (no class text) + role text 12 + optional not-enrolled badge
// hide SacBadge when member.isEnrolled == true
// assign: SacPressable, SizedBox 40×40, icon 18, no filled 36×36 plate
```

Keep existing press:

- `AnimatedScale` via `SacPressable`
- duration `SacMotion.press` = 140ms (budget 100–160ms)
- curve `SacMotion.easeOut` = `Cubic(0.23, 1, 0.32, 1)`
- scale `SacMotion.pressScale` = 0.97
- `SacMotion.reduceMotionOf` already drops scale

**List**

- card `padding: EdgeInsets.only(bottom: 6)` (was 10)
- post-header / trailing `SizedBox(height: 6)` (was 8)

**Filter clip**

```dart
/* members_view.dart _MembersTab.build */
final c = context.sac;
return Column(
  children: [
    ColoredBox(
      color: c.background,
      child: Padding(
        padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 8),
        child: const MembersFilterBar(),
      ),
    ),
    Expanded(
      child: ClipRect(
        child: membersAsync.when(/* unchanged */),
      ),
    ),
  ],
);
```

## Repo conventions to follow

- Motion tokens only from `sacdia-app/lib/core/animations/motion_tokens.dart`.
- Pressable rows use `SacPressable` (`sacdia-app/lib/core/widgets/sac_pressable.dart`).
- Class logo keys stay: `ValueKey('member-card-class-logo-${member.currentClass}')` and `'member-card-class-fallback-icon'`.
- Colors via `context.sac` / `AppColors`.
- No new packages. No `StaggeredListItem` on this list.

## Steps

1. Rewrite `MemberCard` body to a 2-line `Row`: 36px `_MemberAvatar`, name + one meta row, trailing assign/chevron. Drop class **text**. Keep class **logo** at 16×16. Render `_EnrollmentBadge` only when `!member.isEnrolled`.
2. Shrink `_MemberAvatar` to 36, border 1.5, `memCacheWidth/Height: 72`, initials `fontSize: 12`.
3. Replace `_AssignRoleButton` `GestureDetector`+36 filled box with `SacPressable` + 40×40 hit + 18px icon, no fill (or `primary.withValues(alpha: 0.08)` at most 28×28 visual).
4. In `_MembersTab`, wrap filter `Padding` in `ColoredBox(color: c.background)` and wrap list `when` in `ClipRect`.
5. Reduce list gaps 10→6 and header spacers 8→6.
6. Update `test/features/members/presentation/widgets/member_card_test.dart`:
   - `find.text('Amigo')` must be `findsNothing` (logo key still present).
   - enrolled default: `find.text('Inscrito')` is `findsNothing`.
   - `isEnrolled: false` shows `No inscrito`.
   - `tester.getSize(find.byType(MemberCard)).height <= 64`.
7. Run `flutter test test/features/members/presentation/widgets/member_card_test.dart` from `sacdia-app`. Do not run a full app build.

## Boundaries

- Do NOT touch TYPE_JUMP / age-9 / annual-continuations eligibility.
- Do NOT change `MembersModeSwitcher` motion (001).
- Do NOT add list enter/stagger/height animations.
- Do NOT animate padding, height, or layout.
- Do NOT restyle `JoinRequestCard` or continuation rows in this plan.
- Do NOT invent new easing tokens.
- Do NOT bump avatar back to 48 (July 2026 compact spec is superseded by this plan).

## Verification

- **Mechanical**: `flutter test test/features/members/presentation/widgets/member_card_test.dart` — all pass.
- **Feel check** (iOS, Miembros tab, Compañero group):
  - Four enrolled rows fit without the previous three-line stack.
  - Class word is only in the group header, not on every row.
  - No green «Inscrito» pills on enrolled members; «No inscrito» still shows when filtered to that state.
  - Scroll the list under the chips: no ghosted header/card text in the chip gaps.
  - Press a row: scale 0.97 in 140ms ease-out; reduced motion = no scale.
  - Assign icon still opens role assignment without navigating to profile.
- **Done when**: card height ≤ 64 in the widget test, enrolled badge absent on enrolled fixtures, filter bar opaque, press tokens unchanged.
