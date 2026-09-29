# Animation plans — sacdia-app

| # | Title | Severity | Status |
|---|---|---|---|
| 001 | Redesign Members screen tabs, press, and tab motion | HIGH | DONE |
| 002 | Densify Members roster cards; clip list under filters | HIGH | DONE |
| 003 | Densify join-request and not-enrolled rows | HIGH | DONE |
| 004 | Redesign Materiales catalog chrome | HIGH | DONE |
| 005 | Raise Materiales chrome to 44pt hits without fat pills | HIGH | DONE |

## Execution order

## Execution order

1. `001-members-screen-redesign.md` — no dependencies.
2. `002-member-cards-density.md` — after 001 (needs `SacPressable` on the card).
3. `003-join-and-unenrolled-density.md` — after 002 (same density numbers).
4. `004-materials-catalog-chrome.md` — no members dependency. Needs compact `SacFilterChip` (28px visual) already on the branch.
5. `005-materials-catalog-a11y.md` — after 004. Visual 28 stays; hit/track becomes 44. Quiet selected uses `primaryLight` / `primaryDark`.

Run with any agent against current `sacdia-app` `development` (commit stamped in the plan). Do not start from a new worktree unless asked.
