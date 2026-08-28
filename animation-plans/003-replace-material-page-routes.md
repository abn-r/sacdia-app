# 003 — Replace leftover MaterialPageRoute with Sac routes

- **Status**: DONE
- **Commit**: `0ef841cd`
- **Severity**: HIGH
- **Category**: Cohesion / easing & duration
- **Estimated scope**: 2 route constructors + ~40 production files, existing transition tests, ~80–150 lines (mostly 1-line swaps)

## Problem

GoRouter already uses `sharedAxisPage` / `fadeThroughPage` / `slideUpPage` (`SacMotion.routeEnter` = 240ms, `routeExit` = 200ms, `easeOut` = `Cubic(0.23, 1, 0.32, 1)`, drawer = `Cubic(0.32, 0.72, 0, 1)`).

`Navigator.push` still opens ~60 `MaterialPageRoute`s. Material’s default (~300ms, different curve) makes those pushes feel like a second app.

```dart
/* lib/features/activities/presentation/views/activity_detail_view.dart:139-142 — current */
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EditActivityView(activity: activity)),
    );
```

Drop-in replacements already exist and are used in Finances / Inventory / Club:

```dart
/* lib/core/animations/page_transitions.dart:183-191 — current */
class SacSharedAxisRoute<T> extends PageRouteBuilder<T> {
  SacSharedAxisRoute({required WidgetBuilder builder, super.settings})
      : super(
          transitionDuration: SacMotion.routeEnter,
          reverseTransitionDuration: SacMotion.routeExit,
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionsBuilder: _buildSharedAxisTransition,
        );
}
```

`SacFadeThroughRoute` / `SacSlideUpRoute` do **not** expose `fullscreenDialog` today. Image viewer and location pickers pass `fullscreenDialog: true` into `MaterialPageRoute`. That flag must survive.

## Target

- Forward/back pages → `SacSharedAxisRoute` (240ms in / 200ms out, `SacMotion.easeOut`, 4% horizontal slide). Reduced motion already zeroes the slide in `_buildSharedAxisTransition`.
- Location pickers → `SacSlideUpRoute` (same durations, `SacMotion.drawer` = `Cubic(0.32, 0.72, 0, 1)`, `translateY(100%)` via `Offset(0, 1)`).
- Fullscreen media (image / PDF / local preview) → `SacFadeThroughRoute` (160ms both ways, opacity only).

Add `super.fullscreenDialog` to the three route constructors so existing `fullscreenDialog: true` compiles:

```dart
/* target constructors */
class SacSharedAxisRoute<T> extends PageRouteBuilder<T> {
  SacSharedAxisRoute({
    required WidgetBuilder builder,
    super.settings,
    super.fullscreenDialog,
  }) : super(
          transitionDuration: SacMotion.routeEnter,
          reverseTransitionDuration: SacMotion.routeExit,
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionsBuilder: _buildSharedAxisTransition,
        );
}

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

class SacSlideUpRoute<T> extends PageRouteBuilder<T> {
  SacSlideUpRoute({
    required WidgetBuilder builder,
    super.settings,
    super.fullscreenDialog,
  }) : super(
          transitionDuration: SacMotion.routeEnter,
          reverseTransitionDuration: SacMotion.routeExit,
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionsBuilder: _buildSlideUpTransition,
        );
}
```

Do not change transition builders, durations, or curves.

## Repo conventions to follow

```dart
/* lib/features/finances/presentation/views/finances_view.dart:248-251 — exemplar shared-axis */
    Navigator.push(
      context,
      SacSharedAxisRoute(builder: (_) => TransactionDetailView(transaction: t)),
    );
```

```dart
/* lib/features/club/presentation/views/club_view.dart:120-128 — exemplar slide-up picker */
    final result = await Navigator.push<LocationPickerResult>(
      context,
      SacSlideUpRoute(
        builder: (_) => LocationPickerView(
          initialLocation: _selectedLocation != null
              ? LatLng(_selectedLocation!.lat, _selectedLocation!.long)
              : null,
        ),
      ),
    );
```

Import: `package:sacdia_app/core/animations/page_transitions.dart`

Keep generics: `MaterialPageRoute<void>(` → `SacSharedAxisRoute<void>(`. Keep `Navigator.push<T>` type args.

## Steps

1. Update the three constructors in `lib/core/animations/page_transitions.dart` as in Target. No other edits in that file.
2. **Location pickers → `SacSlideUpRoute`**. Drop `fullscreenDialog: true` (Club already did). Slide-up is the modal language.

   | File | Line |
   | --- | --- |
   | `lib/features/activities/presentation/views/create_activity_view.dart` | 147 |
   | `lib/features/activities/presentation/views/edit_activity_view.dart` | 190 |
   | `lib/features/enrollment/presentation/views/enrollment_form_view.dart` | 307 |

3. **Media → `SacFadeThroughRoute`**. Keep `fullscreenDialog: true` only where it exists today (`sac_image_viewer.dart`).

   | File | Line | Notes |
   | --- | --- | --- |
   | `lib/core/widgets/sac_image_viewer.dart` | 57 | `SacFadeThroughRoute(..., fullscreenDialog: true)` |
   | `lib/core/widgets/sac_pdf_viewer.dart` | 40 | no fullscreenDialog today — do not add one |
   | `lib/core/widgets/evidence_staging/staged_file_grid.dart` | 463 | local image preview scaffold |
   | `lib/features/coordinator/presentation/widgets/evidence_file_gallery.dart` | 144 | `_FullscreenImageViewer` |

4. **Everything else in this table → `SacSharedAxisRoute`** (or `SacSharedAxisRoute<void>` if the old type was `<void>`).

   | File | Line |
   | --- | --- |
   | `lib/features/transfers/presentation/views/transfer_requests_view.dart` | 104 |
   | `lib/features/profile/presentation/widgets/profile_classes_section.dart` | 65, 205 |
   | `lib/features/profile/presentation/views/settings_view.dart` | 710, 723, 737, 750, 762, 865 |
   | `lib/features/profile/presentation/views/profile_view.dart` | 197, 201, 406, 430 |
   | `lib/features/profile/presentation/views/medical_info_view.dart` | 164, 186, 217, 237, 266, 286, 315, 335, 368 |
   | `lib/features/activities/presentation/views/activity_detail_view.dart` | 141, 473, 481 |
   | `lib/features/post_registration/presentation/views/personal_info_step_view.dart` | 702, 710, 718, 726, 734 |
   | `lib/features/post_registration/presentation/views/emergency_contacts_view.dart` | 75 |
   | `lib/features/accessibility/presentation/widgets/accessibility_settings_section.dart` | 24 |
   | `lib/features/investiture/presentation/views/investiture_submit_view.dart` | 366 |
   | `lib/features/investiture/presentation/views/investiture_pending_list_view.dart` | 333 |
   | `lib/features/camporees/presentation/views/camporee_members_view.dart` | 95 |
   | `lib/features/camporees/presentation/views/camporees_list_view.dart` | 88 |
   | `lib/features/camporees/presentation/views/camporee_detail_view.dart` | 232, 516, 990, 1146 |
   | `lib/features/certifications/presentation/views/certification_detail_view.dart` | 400 |
   | `lib/features/certifications/presentation/views/my_certifications_view.dart` | 263 |
   | `lib/features/certifications/presentation/views/certifications_list_view.dart` | 121, 152 |
   | `lib/features/enrollment/presentation/widgets/enrollment_status_card.dart` | 74, 101 |
   | `lib/features/members/presentation/views/members_view.dart` | 334, 349, 465 |
   | `lib/features/classes/presentation/views/class_detail_view.dart` | 161 |
   | `lib/features/classes/presentation/views/classes_list_view.dart` | 193, 241 |
   | `lib/features/classes/presentation/views/class_members_progress_view.dart` | 120 |
   | `lib/features/classes/presentation/views/teaching_scope_view.dart` | 74, 186 |
   | `lib/features/classes/presentation/roadmap/widgets/roadmap_screen_connected.dart` | 41 |

5. Add the page_transitions import to every edited file that lacks it.
6. Leave `lib/features/activities/presentation/views/activities_list_view.dart:1103` commented `MaterialPageRoute` commented. Do not uncomment it.
7. After edits, `rg 'MaterialPageRoute\\(' lib --glob '*.dart'` must only hit:
   - comments / docs in `page_transitions.dart`
   - the commented line in `activities_list_view.dart`
   - this plan file (not in `lib/`)

## Boundaries

- Do NOT change go_router `pageBuilder`s in `lib/core/config/router.dart`.
- Do NOT change `_buildSharedAxisTransition` / fade / slide-up builders, durations, or curves.
- Do NOT replace `showModalBottomSheet` (different finding).
- Do NOT add packages.
- Do NOT restyle destination pages.
- If a listed line is no longer `MaterialPageRoute`, STOP and report.

## Verification

- **Mechanical**: `flutter test test/core/animations/shared_axis_transition_test.dart` — pass. `rg` check in step 7.
- **Feel check**:
  - Actividades → detalle → Editar: incoming page slides ~4% from the right and fades, 240ms, ease-out (starts moving immediately). Back: 200ms, same curve flipped.
  - Crear actividad → picker de mapa: sheet slides up from the bottom with the drawer curve, not a Material right-slide.
  - Abrir una imagen fullscreen (`SacImageViewer`): fade only, 160ms, no horizontal slide. `fullscreenDialog` still covers the tab bar.
  - iOS Simulator → Slow Animations: shared-axis never eases in; reduced motion (in-app) drops the slide, fade remains.
- **Done when**: no live `MaterialPageRoute(` in `lib/` except the commented activities line and docs; location pickers use `SacSlideUpRoute`; media uses `SacFadeThroughRoute`; constructors accept `fullscreenDialog`.
