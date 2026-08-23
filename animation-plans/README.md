# Animation plans

`plans/` already holds the older motion-unification work (`001-unify-motion`, DONE). New motion specs live here.

| Plan | Title | Severity | Status |
| --- | --- | --- | --- |
| [001](001-login-club-constellation.md) | Add floating club emblems on login laterals | LOW | DONE |
| [002](002-staggered-list-token-defaults.md) | Snap staggered-list defaults to SacMotion tokens | HIGH | DONE |
| [003](003-replace-material-page-routes.md) | Replace leftover MaterialPageRoute with Sac routes | HIGH | DONE |
| [004](004-sac-card-press-scale.md) | SacCard press scale instead of InkWell splash | HIGH | DONE |
| [005](005-honor-enroll-cta-press.md) | Honor enroll CTA: press on down, enroll immediately | HIGH | DONE |

## Recommended execution order

1. `002` — changes the shared list primitive. Do this first; later feel-checks assume 200ms / 40ms lists.
2. `004` — one widget, high traffic. Independent of 002/003.
3. `005` — one CTA. Independent. Same press numbers as 004 (`0.97` / `140ms` / `SacMotion.easeOut`).
4. `003` — largest diff (mechanical route swaps). Do last so review stays a table of replacements, not mixed with motion-token edits.

`002` ∥ `004` ∥ `005` can run in parallel. `003` has no code dependency on them; order is for review load only.

## Dependencies

- Tokens already exist in `lib/core/animations/motion_tokens.dart`. Do not invent new curves or durations.
- `003` uses existing `SacSharedAxisRoute` / `SacSlideUpRoute` / `SacFadeThroughRoute`. Only additive change: `fullscreenDialog` on those constructors.
- No new packages.
- Stamped against `0ef841cd`.
- Do not revert login/splash/Club motion. Those screens already consume tokens.

## Out of this batch

Audit findings 5–12 (unlock `scale(0)`, sheets, skeleton reduced-motion, theme-picker bounce, date-strip `AnimatedSize`, etc.) have no plans yet.
