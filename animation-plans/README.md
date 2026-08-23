# Animation plans

`plans/` already holds the older motion-unification work (`001-unify-motion`, DONE). New motion specs live here.

| Plan | Title | Severity | Status |
| --- | --- | --- | --- |
| [001](001-login-club-constellation.md) | Add floating club emblems on login laterals | LOW | DONE |
| [002](002-staggered-list-token-defaults.md) | Snap staggered-list defaults to SacMotion tokens | HIGH | DONE |
| [003](003-replace-material-page-routes.md) | Replace leftover MaterialPageRoute with Sac routes | HIGH | DONE |
| [004](004-sac-card-press-scale.md) | SacCard press scale instead of InkWell splash | HIGH | DONE |
| [005](005-honor-enroll-cta-press.md) | Honor enroll CTA: press on down, enroll immediately | HIGH | DONE |
| [006](006-achievement-unlock-enter-scale.md) | Achievement unlock: enter from 0.96, honor Reduced Motion | HIGH | DONE |
| [007](007-show-sac-sheet.md) | One sheet language: showSacSheet + SacMotion.drawer | MEDIUM | TODO |
| [008](008-sac-pressable.md) | One press primitive: SacPressable | MEDIUM | DONE |
| [009](009-skeleton-reduced-motion.md) | Freeze loading skeletons under Reduced Motion | MEDIUM | DONE |

## Recommended execution order

**Already shipped** (`bff0a6bf`): 002 → 004 → 005 → 003.

**This batch (findings 5–8):**

1. `008` — small shared widget. Press numbers must match `SacButton` / `SacCard` before more surfaces copy a local variant.
2. `006` — isolated unlock overlay. No file overlap with 008/009.
3. `009` — isolated skeleton files. No overlap with 006/008.
4. `007` — largest diff (~48 sheet call sites). Do last so review stays a swap table.

`006` ∥ `008` ∥ `009` can run in parallel. `007` has no code dependency on them; order is for review load.

## Dependencies

- Tokens already exist in `lib/core/animations/motion_tokens.dart`. Do not invent new curves or durations.
- `007` uses Flutter `AnimationStyle` (already used in `camporee_section_registration_sheet.dart`). Lift that into `showSacSheet`; then that file uses the helper.
- `008` must keep Club address as `listenOnly: true` (child owns the tap).
- `009` must not touch `ranking_skeleton.dart` (already correct — copy it).
- No new packages.
- New plans stamped against `bff0a6bf`.
- Do not revert login/splash/Club/`SacCard` motion from 002–005.

## Out of this batch

Findings 9–12 (theme-picker `easeOutBack`, activities date-strip `AnimatedSize`, virtual-card `easeInCubic`, inventory `elasticOut`) have no plans yet.
