# 001 — Unify motion and fix high-leverage transitions

- **Status**: DONE
- **Commit**: `57e6334`
- **Severity**: HIGH
- **Category**: Accessibility, easing & duration, purpose & frequency, physicality, cohesion
- **Estimated scope**: 12–16 production files, 6–8 focused test files, roughly 350–500 changed lines

## Problem

SACDIA has good Flutter motion primitives, but the five highest-leverage findings
share one root problem: motion policy is distributed across widgets instead of
being expressed once and consumed consistently.

Repository root for every path in this plan:

```text
/Users/abner/Documents/development/sacdia/sacdia-app
```

### 1. Reduced Motion is propagated but not consumed consistently

The app correctly merges the user preference into `MediaQuery.disableAnimations`:

```dart
// lib/features/accessibility/presentation/providers/accessibility_provider.dart:58-66 — current
MediaQueryData mergedAccessibilityMediaQueryData(
  MediaQueryData base,
  AccessibilitySettings settings,
) {
  final factor = settings.textScaleFactor;
  return base.copyWith(
    textScaler: factor != null ? TextScaler.linear(factor) : base.textScaler,
    disableAnimations: settings.reduceMotion || base.disableAnimations,
  );
}
```

However, shared widgets start custom controllers without reading that value:

```dart
// lib/core/widgets/sac_card.dart:54-70 — current
_controller = AnimationController(
  vsync: this,
  duration: const Duration(milliseconds: 320),
);

_fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

_scale = Tween<double>(begin: 0.94, end: 1.0).animate(
  CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
);

if (widget.animate) {
  Future.delayed(widget.animationDelay, () {
    if (mounted) _controller.forward();
  });
}
```

`AchievementBadge` also starts infinite shimmer/pulse loops without checking the
preference, despite the canonical feature requirement explicitly saying those
controllers must not start under Reduced Motion:

```dart
// lib/features/achievements/presentation/widgets/achievement_badge.dart:87-98 — current
if (widget.visualState == AchievementVisualState.unlocked) {
  if (widget.tier == AchievementTier.platinum ||
      widget.tier == AchievementTier.diamond) {
    _shimmerController.repeat(reverse: true);
  }

  if (widget.tier == AchievementTier.diamond) {
    _pulseController.repeat(reverse: true);
  }
}
```

The same gap exists in:

- `lib/core/animations/staggered_list_animation.dart`
- `lib/core/animations/animated_counter.dart`
- `lib/core/widgets/sac_dialog.dart`
- `lib/core/widgets/sac_progress_bar.dart`
- `lib/core/widgets/sac_progress_ring.dart`
- `lib/core/widgets/sac_loading.dart`

### 2. Activity list motion is compounded three times

Every row gets a staggered fade/slide:

```dart
// lib/features/activities/presentation/views/activities_list_view.dart:443-459 — current
final activity = item as Activity;
return StaggeredListItem(
  index: index,
  child: ActivityCard(
    activity: activity,
    onTap: () { /* navigation */ },
  ),
);
```

`ActivityCard` independently enables another fade/back-scale entrance:

```dart
// lib/features/activities/presentation/widgets/activity_card.dart:76-81 — current
return SacCard(
  onTap: onTap,
  margin: const EdgeInsets.only(bottom: 12),
  padding: const EdgeInsets.all(16),
  animate: true,
  child: Column(
```

The whole list is then moved again by a 320ms switcher:

```dart
// lib/features/activities/presentation/views/activities_list_view.dart:496-509 — current
return AnimatedSwitcher(
  duration: const Duration(milliseconds: 320),
  switchInCurve: Curves.easeOut,
  switchOutCurve: Curves.easeIn,
  transitionBuilder: (child, animation) => FadeTransition(
    opacity: animation,
    child: SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0.04, 0),
        end: Offset.zero,
      ).animate(animation),
      child: child,
    ),
  ),
  child: content,
);
```

This routine screen therefore combines opacity, translation, back-scale, and a
second translation instead of using one comprehensible transition.

### 3. Shared route transitions start slowly and are used for the wrong purpose

```dart
// lib/core/animations/page_transitions.dart:28-50 — current
transitionDuration: const Duration(milliseconds: 340),
reverseTransitionDuration: const Duration(milliseconds: 280),

final slideOut = Tween<Offset>(
  begin: Offset.zero,
  end: const Offset(-0.04, 0),
).animate(CurvedAnimation(
  parent: secondaryAnimation,
  curve: Curves.easeInCubic,
));

final fadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(
  CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeIn),
);
```

The slow-start exit affects routine navigation. In addition,
`_fadeThroughBuild` is documented for peer/tab switching but is assigned to
dashboard modules opened with `context.push`, losing directional drill-in
context.

### 4. Dashboard content is delayed by decorative stagger

```dart
// lib/features/dashboard/presentation/views/dashboard_view.dart:92-110 — current
StaggeredListItem(
  index: 0,
  initialDelay: const Duration(milliseconds: 60),
  child: WelcomeHeader(...),
),

Padding(
  padding: EdgeInsets.symmetric(horizontal: hPad),
  child: StaggeredColumn(
    initialDelay: const Duration(milliseconds: 120),
    staggerDelay: const Duration(milliseconds: 80),
    children: [
```

The `children` list includes both functional content and `SizedBox` spacing.
Later dashboard modules can finish more than one second after the data is ready.
The dashboard is a high-frequency operational surface, not a rare reveal.

### 5. Honor detail creates its hero badge from literal scale zero

```dart
// lib/features/honors/presentation/views/honor_detail_view.dart:657-675,714-715 — current
_controller = AnimationController(
  vsync: this,
  duration: const Duration(milliseconds: 600),
);

_badgeScale = CurvedAnimation(
  parent: _controller,
  curve: Curves.elasticOut,
);

Future.delayed(const Duration(milliseconds: 80), () {
  if (mounted) _controller.forward();
});

ScaleTransition(
  scale: _badgeScale,
```

A default-zero controller directly drives scale, so the badge is absent for 80ms
and then grows from nothing over 600ms. This is too theatrical for every detail
view and violates the physicality rule against `scale(0)`.

## Target

### Motion foundation

Create `lib/core/animations/motion_tokens.dart` with exactly this policy:

```dart
import 'package:flutter/material.dart';

abstract final class SacMotion {
  // Exact strong curves from the animation audit playbook.
  static const Curve easeOut = Cubic(0.23, 1, 0.32, 1);
  static const Curve easeInOut = Cubic(0.77, 0, 0.175, 1);
  static const Curve drawer = Cubic(0.32, 0.72, 0, 1);

  // Interaction durations stay below 300ms.
  static const Duration press = Duration(milliseconds: 140);
  static const Duration reducedFade = Duration(milliseconds: 160);
  static const Duration standard = Duration(milliseconds: 200);
  static const Duration routeEnter = Duration(milliseconds: 240);
  static const Duration routeExit = Duration(milliseconds: 200);
  static const Duration modal = Duration(milliseconds: 240);
  static const Duration stagger = Duration(milliseconds: 40);

  static const double enterScale = 0.96;

  static bool reduceMotionOf(BuildContext context) =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;
}
```

Do not add a second token class or duplicate these values in feature files.

### Reduced Motion behavior

Apply these exact rules:

| Motion type | Normal | Reduced Motion |
|---|---|---|
| Route drill-in | 4% horizontal slide + fade, 240ms | Fade only, 160–240ms |
| Peer/fade route | Fade, 160ms | Fade, 160ms |
| List/dashboard entrance | None on routine surfaces | None |
| Dialog | `0.96 → 1` + fade, 240ms | Fade only, 160ms |
| Counter/progress entrance | Existing target value transition | Render final value immediately |
| Achievement shimmer/pulse | Existing documented loop | Controllers stopped; stable frame |
| Loading indicator | Existing moving dots | Static three-dot mark with identical size/color |

Controller-owning widgets that depend on `MediaQuery` must react in
`didChangeDependencies`, not only in `initState`. Cancel delayed starts when the
preference changes. `RankingSkeleton` at
`lib/features/rankings/presentation/widgets/ranking_skeleton.dart:63-77` is the
existing lifecycle exemplar.

### Route behavior

- Shared-axis route: `240ms` enter, `200ms` reverse, `SacMotion.easeOut` for
  incoming and outgoing motion.
- Incoming offset: `Offset(0.04, 0)`; outgoing offset: `Offset(-0.03, 0)`.
- Fade-through route: `160ms`, `SacMotion.easeOut`, opacity only.
- Slide-up route: keep the full-height spatial relationship, but use
  `SacMotion.drawer` and `240ms`; Reduced Motion uses fade only.
- Convert dashboard quick-access routes opened by
  `lib/features/dashboard/presentation/widgets/quick_access_grid.dart:332`
  from `_fadeThroughBuild` to `_sharedAxisBuild`.
- Preserve `StatefulShellRoute.indexedStack`; do not replace the router.

### Activities and dashboard

- Remove `StaggeredListItem` around activity rows in both list modes.
- Set `ActivityCard` to `animate: false` or remove the explicit animation
  argument if the default remains false.
- Keep one `AnimatedSwitcher` for list-mode replacement: pure fade,
  `SacMotion.standard`, `SacMotion.easeOut`; no `SlideTransition`.
- Replace dashboard `StaggeredListItem`/`StaggeredColumn` wrappers with ordinary
  `Column` composition while preserving the exact widget order and spacing.
- Do not remove documented stagger from finances, certifications, honors, or
  other feature specs in this plan. Remaining `StaggeredListItem` uses must only
  gain automatic Reduced Motion support.

### Honor hero

Replace the implicit `0 → 1` elastic animation with:

```dart
_controller = AnimationController(
  vsync: this,
  duration: SacMotion.routeEnter,
);

_badgeScale = Tween<double>(
  begin: SacMotion.enterScale,
  end: 1,
).animate(
  CurvedAnimation(parent: _controller, curve: SacMotion.easeOut),
);
```

Start immediately, with no 80ms delay. Under Reduced Motion, set the controller
to `1` without starting it. Keep the existing progress value readable and at its
final value when motion is reduced.

## Repo conventions to follow

- Shared UI primitives live under `lib/core/`; feature-specific composition stays
  under `lib/features/<feature>/presentation/`.
- `MediaQuery.disableAnimations` is the canonical merged system/user preference;
  do not read `SharedPreferences` or Riverpod directly from animation widgets.
- `lib/features/rankings/presentation/widgets/ranking_skeleton.dart:63-77`
  demonstrates how a controller reacts when accessibility dependencies change.
- `lib/features/virtual_card/presentation/widgets/credencial/credential_parallax.dart:77-81`
  demonstrates the canonical `MediaQuery.maybeOf(context)?.disableAnimations`
  read.
- Use Flutter primitives only. Do not add Lottie, Rive, or another animation
  dependency.

## Steps

1. **Add the motion policy.**
   - Create `lib/core/animations/motion_tokens.dart` exactly as specified above.
   - Add `test/core/animations/motion_tokens_test.dart` covering the constant
     values and `reduceMotionOf` for `true` and `false` MediaQuery data.

2. **Make shared primitives consume Reduced Motion.**
   - Update `lib/core/animations/staggered_list_animation.dart` so direct
     `StaggeredListItem` use reads the preference, cancels delayed starts, and
     renders its child immediately when reduced.
   - Update `lib/core/animations/animated_counter.dart` so initial and subsequent
     values settle immediately when reduced; do not display a stale zero.
   - Update `lib/core/widgets/sac_card.dart` to use `SacMotion` tokens, cancel its
     delayed start, and bypass entrance motion when reduced.
   - Update `lib/core/widgets/sac_dialog.dart` to use `0.96 → 1` normally and a
     160ms opacity-only entrance when reduced.
   - Update `lib/core/widgets/sac_progress_bar.dart` and
     `lib/core/widgets/sac_progress_ring.dart` to settle to the target value and
     skip shimmer when reduced.
   - Update `lib/core/widgets/sac_loading.dart` so `SacLoading` and
     `SacLoadingSmall` render a static, same-size three-dot mark when reduced.
   - Add focused widget tests for every changed shared primitive. Tests must toggle
     `MediaQueryData.disableAnimations` after mount to prove controllers react to
     dependency changes, not only initial construction.

3. **Honor the achievement accessibility contract.**
   - Update `lib/features/achievements/presentation/widgets/achievement_badge.dart`.
   - Move loop synchronization to a dependency-aware method.
   - When reduced, stop both controllers and set stable values; never call
     `repeat()`.
   - Preserve the exact normal-motion behavior documented in
     `../docs/achievements-ui-redesign-spec.md:551-559`.
   - Add a widget test proving an unlocked diamond badge does not keep scheduling
     animation frames under Reduced Motion and still renders its badge/star.

4. **Correct shared route motion.**
   - Update both `CustomTransitionPage` helpers and `PageRouteBuilder` classes in
     `lib/core/animations/page_transitions.dart` with the target durations,
     offsets, and curves.
   - Reduced Motion must retain opacity feedback but remove positional movement.
   - Update `lib/core/config/router.dart` so dashboard quick-access drill-ins use
     `_sharedAxisBuild`; keep peer/root branch routes on `_fadeThroughBuild`.
   - Add route widget tests for normal and reduced motion. At 10% playback or
     intermediate pump time, assert reduced motion has zero slide offset.

5. **Remove compounded activity motion.**
   - Update both activity list builders in
     `lib/features/activities/presentation/views/activities_list_view.dart` to
     return `ActivityCard` directly.
   - Replace the 320ms fade/slide switcher with one 200ms pure fade using
     `SacMotion.easeOut`.
   - Disable the internal entrance in
     `lib/features/activities/presentation/widgets/activity_card.dart`.
   - Add a widget test proving an activity row has no nested `SlideTransition` or
     entrance `ScaleTransition`, while list-mode replacement still fades.

6. **Make the dashboard immediate.**
   - Update `lib/features/dashboard/presentation/views/dashboard_view.dart`.
   - Remove the outer `StaggeredListItem` and `StaggeredColumn` only; preserve all
     children, permissions, loading/error states, refresh behavior, and spacing.
   - Add a widget test that pumps the loaded dashboard once and finds late content
     immediately without advancing animation time.

7. **Fix honor hero physicality.**
   - Update `_HeroSectionState` in
     `lib/features/honors/presentation/views/honor_detail_view.dart` with the exact
     target tween and duration.
   - Remove the delayed start.
   - Under Reduced Motion, render scale `1` and final progress immediately.
   - Add a focused widget test or extract the private hero motion into a small
     testable presentation widget without changing its public screen contract.

8. **Synchronize documentation.**
   - Update the mobile motion/accessibility section in the closest active feature
     documentation only if existing statements become inaccurate.
   - Do not modify API, database, or backend documentation; this plan changes no
     contract or business behavior.

## Boundaries

- Do **not** edit
  `lib/features/finances/presentation/views/add_transaction_sheet.dart` or
  `test/features/finances/presentation/`; they contain unrelated user work.
- Do **not** edit `lib/features/dashboard/presentation/views/animation_demo_view.dart`;
  it is an intentional temporary laboratory, not production motion policy.
- Do **not** remove stagger that is explicitly required by an active feature spec,
  including finances. This plan only makes remaining stagger accessibility-safe.
- Do **not** implement the lower-priority audit findings: birthday confetti,
  roadmap tickers, skeleton controller consolidation, credential parallax, or new
  celebration opportunities.
- Do **not** change routes, endpoint contracts, providers, schema, permissions,
  business logic, visual hierarchy, or copy.
- Do **not** add dependencies.
- Do **not** run a Flutter build.
- If the commit stamp no longer matches or any cited code has materially drifted,
  stop and report the mismatch instead of improvising.

## Verification

- **Mechanical**:
  1. Run `dart format` only on files changed by this plan.
  2. Run `flutter analyze`; expected result: no new diagnostics.
  3. Run the focused tests created by this plan with `flutter test <test paths>`;
     expected result: all pass.
  4. Run existing accessibility/parallax coverage:
     `flutter test test/features/virtual_card/presentation/widgets/credencial/credential_parallax_test.dart`.
  5. Do not run `flutter build`.

- **Feel check — normal motion**:
  - Navigate repeatedly through dashboard quick-access modules. Entry must begin
    immediately, preserve direction, and finish in 240ms.
  - Toggle activity list modes rapidly. Only opacity may transition; rows must not
    slide, bounce, or scale independently.
  - Open the dashboard after data is cached. All functional sections must be
    available immediately.
  - Open multiple honor details. The badge must already exist at 96% scale and
    settle once without elastic overshoot.
  - Open a SACDIA dialog. It must scale subtly from 0.96, not pop from 0.82.

- **Feel check — Reduced Motion**:
  - Enable SACDIA's Reduce Motion setting without restarting the app.
  - Routes and dialogs retain a gentle fade but perform no slide, scale, pulse,
    shimmer, or stagger.
  - Activity rows, dashboard content, counters, progress, loaders, and achievement
    badges are immediately stable.
  - Disable Reduce Motion again and confirm eligible normal motion resumes without
    remounting the whole app.

- **Performance check**:
  - In Flutter DevTools, inspect the frame chart while switching activity modes and
    opening the dashboard. No frame should contain multiple nested row entrance
    animations.
  - At 10% animation speed, verify outgoing routes start immediately rather than
    waiting on an ease-in curve.

- **Done when**:
  - The five selected findings are implemented under one shared motion policy.
  - Reduced Motion works after runtime toggling and matches the behavior table.
  - Routine dashboard/activity content is never delayed by decorative entrances.
  - Shared navigation uses the specified timing/easing and correct spatial model.
  - Honor badges never animate from scale zero.
  - Focused tests and `flutter analyze` pass, and no build was run.
