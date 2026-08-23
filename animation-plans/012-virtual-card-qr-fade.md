# 012 — Virtual-card QR: SacFadeThroughRoute, drop easeInCubic

- **Status**: DONE
- **Commit**: `fbee25b1`
- **Severity**: MEDIUM
- **Category**: Easing & duration / cohesion
- **Estimated scope**: 1 file, ~20–40 lines

## Problem

QR fullscreen uses a private `PageRouteBuilder` with Material cubics. Exit is `easeInCubic` — ease-in on UI (starts slow on the dismiss the user is watching). Durations 260/220 sit next to, not on, `SacMotion` route tokens.

```dart
/* lib/features/virtual_card/presentation/views/virtual_card_view.dart:345-362 — current */
Route<void> _credencialQrFullscreenRoute(
  CredencialViewModel vm,
  String heroTag,
) {
  return PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 260),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, __, ___) =>
        CredencialQrFullscreen(vm: vm, heroTag: heroTag),
    transitionsBuilder: (_, animation, __, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(opacity: curved, child: child);
    },
  );
}
```

Call site: `virtual_card_view.dart:165-169` (`Navigator.of(context).push(...)`).

Image/PDF viewers already use `SacFadeThroughRoute` (plan 003). QR is the same kind of overlay: opacity only, no directional slide.

`heroTag` is passed into `CredencialQrFullscreen` but there is **no** `Hero(` in `lib/features/virtual_card/`. Do not add one.

## Target

Delete `_credencialQrFullscreenRoute`. Push `SacFadeThroughRoute` (already defined).

| Property | Value (from the route class — do not re-specify) |
| --- | --- |
| Enter / exit duration | `SacMotion.reducedFade` (`160ms`) both ways |
| Curve | `SacMotion.easeOut` + `FlippedCurve(SacMotion.easeOut)` |
| Reduced motion | handled inside `_buildFadeThroughTransition` |

```dart
/* target call site */
                                        ? () => Navigator.of(context).push(
                                              SacFadeThroughRoute(
                                                builder: (_) =>
                                                    CredencialQrFullscreen(
                                                  vm: vm,
                                                  heroTag: heroTag,
                                                ),
                                              ),
                                            )
```

Do **not** set `fullscreenDialog` (current route does not).

Import: `package:sacdia_app/core/animations/page_transitions.dart`

## Repo conventions to follow

```dart
/* lib/core/animations/page_transitions.dart:198-209 — exemplar */
class SacFadeThroughRoute<T> extends PageRouteBuilder<T> {
  SacFadeThroughRoute({
    required WidgetBuilder builder,
    super.settings,
    super.fullscreenDialog,
  }) : super(
          transitionDuration: SacMotion.reducedFade,
          reverseTransitionDuration: SacMotion.reducedFade,
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionsBuilder: _buildFadeThroughTransition,
        );
}
```

Plan 003: image/PDF → `SacFadeThroughRoute`. Same here.

## Steps

1. `lib/features/virtual_card/presentation/views/virtual_card_view.dart`:
   - Add the page_transitions import.
   - Replace the `push(_credencialQrFullscreenRoute(...))` call as Target.
   - Delete `_credencialQrFullscreenRoute` entirely.
2. Do not edit `credencial_qr_fullscreen.dart`.

## Boundaries

- Do NOT restyle the QR page or the card.
- Do NOT add a `Hero` flight.
- Do NOT use `SacSharedAxisRoute` / `SacSlideUpRoute` (QR is not a hierarchical page or a sheet).
- Do NOT keep `Curves.easeInCubic` / `easeOutCubic`.
- Do NOT add packages.
- If `_credencialQrFullscreenRoute` is already gone when you open the file, STOP and report.

## Verification

- **Mechanical**: `dart analyze lib/features/virtual_card/presentation/views/virtual_card_view.dart`. `rg 'easeInCubic|_credencialQrFullscreenRoute' lib` empty. No `flutter build`.
- **Feel check**:
  - Credencial → tap QR. Fade in 160ms, ease-out (visible immediately). Back: same fade, not a slow start.
  - Slow Animations: opacity only. No slide, no bounce.
  - Reduce Motion on: fade still (route already gates slide elsewhere; this route is fade-only).
- **Done when**: no private route function; live push is `SacFadeThroughRoute`; no Material cubics in this file.
