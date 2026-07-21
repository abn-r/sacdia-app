# Animation plans

| Plan | Title | Severity | Status |
|---|---|---|---|
| [001](001-unify-motion-and-fix-high-leverage-transitions.md) | Unify motion and fix high-leverage transitions | HIGH | DONE |

## Recommended execution order

Execute plan 001 as written. Its internal order is intentional: establish motion
tokens and Reduced Motion behavior first, then update routes and production
surfaces that consume that policy.

## Dependencies

- No external packages are required.
- The plan is stamped against `sacdia-app` commit `57e6334`.
- Preserve unrelated finance changes already present in the working tree.
