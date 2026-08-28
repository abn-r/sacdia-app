# 016 — Progress, parallax, celebration, shimmer: tokens + RM

- **Status**: DONE
- **Commit**: `c4bd3fcc`
- **Severity**: MEDIUM
- **Category**: Cohesion / accessibility
- **Estimated scope**: ~12 files, ~60–90 lines

## Problem

001–015 left value-fill, decorative, and loop motion on raw Material cubics. `SacProgressBar` / `SacProgressRing` / `HeroDonut` already use `SacMotion.easeOut` + RM. The leftovers:

```dart
/* lib/features/virtual_card/presentation/widgets/credencial/credential_parallax.dart:89-110 — current */
        duration: _isInteracting
            ? const Duration(milliseconds: 80)
            : const Duration(milliseconds: 360),
        curve: _isInteracting ? Curves.easeOut : Curves.easeOutCubic,
        // highlight fade: 180ms
        // RM via MediaQuery.disableAnimations, not SacMotion.reduceMotionOf
```

```dart
/* lib/core/animations/animated_counter.dart:53-54 — current */
    this.duration = const Duration(milliseconds: 900),
    this.curve = Curves.easeOutCubic,
```

```dart
/* lib/core/widgets/evidence_staging/upload_progress_sheet.dart:412-415 — current */
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
```

```dart
/* lib/features/coordinator/presentation/widgets/sla_pipeline_chart.dart:101-102 — current */
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOut,
```

```dart
/* celebration_overlay.dart:93-97 — starts forward in post-frame; RM only hides paint */
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _particles = _generateParticles(size);
      _controller.forward();
    });
```

Shimmer loops (009) still use `Curves.easeInOut`, not `SacMotion.easeInOut`. Period **stays 1400 / 1100 / 900**.

Do **not** invent tokens. Fill defaults 700/900/800 stay (value travel, not chrome). Celebration 2200 stays (rare).

## Target

| Surface | Duration | Curve | RM |
| --- | --- | --- | --- |
| Parallax follow | keep `80ms` (tracking, faster than press) | `SacMotion.easeOut` | already disabled; switch predicate to `SacMotion.reduceMotionOf` |
| Parallax settle | `SacMotion.modal` (`240ms`) | `SacMotion.easeOut` | no transform |
| Parallax sheen fade | `SacMotion.standard` (`200ms`) | — | n/a when disabled |
| `AnimatedCounter` default curve | keep 900ms | `SacMotion.easeOut` | already |
| Counter / ring start delay | `SacMotion.modal` (`240ms`) | — | already cancelled |
| Upload overall bar | `SacMotion.modal` | `SacMotion.easeOut` | `Duration.zero` |
| Upload file ring | `SacMotion.standard` | `SacMotion.easeOut` | `Duration.zero` |
| SLA bar width | keep 600ms (no token) | `SacMotion.easeOut` | `Duration.zero` |
| Celebration | keep 2200ms | — | `SacMotion.reduceMotionOf`: no particles, no `forward()`, `onComplete` immediately |
| Shimmer sweep curve | keep 1400/1100/900 | `SacMotion.easeInOut` | already frozen (009) |

```dart
/* target — parallax */
    final enabled = widget.enabled && !SacMotion.reduceMotionOf(context);
    // ...
        duration: _isInteracting ? const Duration(milliseconds: 80) : SacMotion.modal,
        curve: SacMotion.easeOut,
        // sheen:
                    duration: SacMotion.standard,
```

```dart
/* target — celebration start */
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (SacMotion.reduceMotionOf(context)) {
      widget.onComplete?.call();
      return;
    }
    final size = MediaQuery.sizeOf(context);
    _particles = _generateParticles(size);
    _controller.forward();
  }
```

Remove the post-frame `forward()` from `initState`. Build: `SacMotion.reduceMotionOf` → `SizedBox.shrink()`.

Shimmer files (curve only): the eight from 009. **Not** `ranking_skeleton.dart`, **not** `notification_card.dart`.

## Repo conventions to follow

- Tokens: `lib/core/animations/motion_tokens.dart`.
- `SacProgressBar` / `SacProgressRing` — already the fill+RM exemplar. Copy RM, do not restyle.
- 009: shimmer period stays; only the curve token changes.

## Steps

1. `credential_parallax.dart` — import tokens; Target table.
2. `celebration_overlay.dart` — import tokens; start in `didChangeDependencies`; RM skip.
3. `animated_counter.dart` — default `curve: SacMotion.easeOut`; delay `SacMotion.modal`. Comment: drop “easeOutCubic”.
4. `sac_progress_ring.dart` — delay `SacMotion.modal`; comment: `SacMotion.easeOut` not easeOutCubic.
5. `upload_progress_sheet.dart` — two tweens as Target. Add import.
6. `sla_pipeline_chart.dart` — curve token + RM duration zero. Add import.
7. Eight 009 skeletons: `Curves.easeInOut` → `SacMotion.easeInOut` on the shimmer `CurvedAnimation` only.
8. `birthday_celebration.dart` — `MediaQuery.disableAnimations` → `SacMotion.reduceMotionOf`. Durations 2200/2400/1800 stay.

## Boundaries

- Do NOT change shimmer 1400ms (or 1100/900).
- Do NOT change SacProgressBar `fillDuration` 700 / ring 900 / HeroDonut 800 / celebration 2200.
- Do NOT edit `ranking_skeleton.dart` or `notification_card.dart`.
- Do NOT add packages.
- Do NOT restyle chrome.

## Verification

- **Mechanical**: `dart analyze` on touched files. `rg 'easeOutCubic' lib` — no hits in these files. No `flutter build`.
- **Feel check**:
  - Credencial: tilt follows fast; release settles 240ms ease-out. RM: flat card.
  - Upload sheet: bars ease-out, ~240ms. RM: snap.
  - Celebration: burst still ~2.2s. RM: nothing, overlay gone.
  - Skeleton: same period, slightly stronger ease-in-out. RM: frozen (009).
- **Done when**: parallax/celebration/counter/upload/SLA/shimmer-009 use `SacMotion` curves; no new tokens.
