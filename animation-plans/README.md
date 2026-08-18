# Animation plans (login constellation)

`plans/` already holds the older motion-unification work. New motion specs for this login delight live here.

| Plan | Title | Severity | Status |
| --- | --- | --- | --- |
| [001](001-login-club-constellation.md) | Add floating club emblems on login laterals | LOW | DONE |

## Recommended execution order

1. Drop `assets/img/logo-jovenes-adventistas.png` (precondition of 001).
2. Execute `001-login-club-constellation.md` on top of the uncommitted login redesign. Do not revert login/splash.

## Dependencies

- Requires the working-tree login redesign (`LoginView` white canvas + `SacBrandMark`).
- Requires four PNG assets listed in plan 001. Three exist; Jóvenes Adventistas does not.
- No new packages.
- Stamped against `eb9a994`.
