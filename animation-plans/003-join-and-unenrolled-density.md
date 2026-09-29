# 003 — Densify join-request and not-enrolled rows

- **Status**: DONE
- **Commit**: `3c97bd82`
- **Severity**: HIGH
- **Category**: Purpose & frequency (layout density; keep existing press tokens)
- **Estimated scope**: 4 files (`join_request_card.dart`, `members_view.dart`, `annual_continuations_view.dart`, `join_request_card_test.dart`)

## Problem

Plan 002 densified `MemberCard`. Solicitudes and No inscritos still use the old tile: 14px padding, ~44px avatar, extra action row (join requests) or three text lines (continuations). Same screen, same daily scan.

```dart
/* join_request_card.dart:37-42 — current */
padding: const EdgeInsets.all(14),
borderRadius: BorderRadius.circular(14),
// CircleAvatar radius: 22  → 44px + 2px border
// pending: second Row of SacButton small (minHeight 36) after SizedBox(height: 12)
```

```dart
/* annual_continuations_view.dart:222 — current */
padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
// name + currentRole + blocked reason as separate Text widgets
// ListView.separated height: 8
```

Join-request filter chips have the same transparent-gap leak as 002 (`members_view.dart` `_JoinRequestsTab` Padding without `ColoredBox`).

## Target

Match 002 numbers. Press stays `SacPressable` + `SacMotion.press` 140ms + `SacMotion.easeOut` `Cubic(0.23, 1, 0.32, 1)` + `pressScale` 0.97. No list stagger.

**JoinRequestCard**

- padding `EdgeInsets.symmetric(horizontal: 12, vertical: 8)`
- radius 12
- avatar inner 36, border 1.5, initials 12
- one meta line: date only (drop calendar icon)
- pending + `onApprove`/`onReject`: trailing 40×40 `SacPressable` icon hits (visual 28), semantic labels `members.join_request.reject` / `approve`. No second button row. No pending badge when actions are visible (pending is the default).
- approved / rejected / pending without actions: `_StatusBadge` on the trailing edge
- list separator 10 → 6
- wrap search/chips in `ColoredBox(color: c.background)` + `ClipRect` on the list, same as `_MembersTab`

**_ContinuationItem**

- padding `horizontal: 12, vertical: 8`
- checkbox 20
- name 15 w600 height 1.2 maxLines 1
- single meta line: role and/or blocked reason, 12 secondary, ellipsis
- blocked pill stays trailing
- separator 8 → 6

## Repo conventions

Copy `_AssignRoleButton` in `member_card.dart` for the 40/28 icon hit. Tokens only from `motion_tokens.dart`. Do not restyle empty states.

## Steps

1. Rewrite `JoinRequestCard` to a 2-line row; replace `_ActionButton`/`SacButton` with icon `SacPressable`s.
2. Clip + opaque filter on `_JoinRequestsTab`; separator 6.
3. Densify `_ContinuationItem` + separator 6.
4. Add `test/features/members/presentation/widgets/join_request_card_test.dart`: pending+actions height ≤ 64; semantics Rechazar/Aprobar; approved shows `Aprobado` and no those semantics.
5. Run `flutter test test/features/members/presentation/widgets/join_request_card_test.dart test/features/members/annual_membership_flow_test.dart`. No full build.

## Boundaries

- Do NOT change approve/reject/enroll API or eligibility.
- Do NOT add stagger or layout animations.
- Do NOT restyle `MemberCard` again.
- Do NOT change MembersModeSwitcher.

## Verification

- **Mechanical**: those two test files pass.
- **Feel check**: Solicitudes pending row is one row with X / check; scroll does not ghost under chips. No inscritos rows match member-card height; checkbox still toggles; submit bar unchanged.
- **Done when**: pending join card ≤ 64 in test; continuation list still shows `Luis Pérez Soto` + enroll CTA.
