# 007 — One sheet language: showSacSheet + SacMotion.drawer

- **Status**: TODO
- **Commit**: `bff0a6bf`
- **Severity**: MEDIUM
- **Category**: Cohesion / easing & duration / accessibility
- **Estimated scope**: 1 new helper + ~48 call sites (mechanical swap), ~80–120 lines

## Problem

GoRouter and `Navigator` now use `SacMotion` (`routeEnter` 240ms, `routeExit` 200ms, `drawer` = `Cubic(0.32, 0.72, 0, 1)`). Bottom sheets still call raw `showModalBottomSheet` → Material default curve/duration. Two drawer languages.

```dart
/* lib/core/widgets/section_switcher_sheet.dart:31-41 — current */
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SectionSwitcherSheet(
```

```dart
/* lib/features/resources/presentation/widgets/resource_detail_sheet.dart:35-40 — current */
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ResourceDetailSheet(resource: resource),
    );
```

One sheet already customizes motion, but with raw durations and **no drawer curve**:

```dart
/* lib/features/camporees/presentation/widgets/camporee_section_registration_sheet.dart:29-43 — current */
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    return showModalBottomSheet<bool>(
      // ...
      sheetAnimationStyle: disableAnimations
          ? AnimationStyle.noAnimation
          : const AnimationStyle(
              duration: Duration(milliseconds: 200),
              reverseDuration: Duration(milliseconds: 180),
            ),
```

## Target

New function `showSacSheet<T>` in `lib/core/widgets/sac_sheet.dart`. It is the only place that sets `sheetAnimationStyle`.

| Property | Value |
| --- | --- |
| Enter duration | `SacMotion.modal` = `240ms` |
| Exit duration | `SacMotion.routeExit` = `200ms` (exit faster than enter) |
| Curve both ways | `SacMotion.drawer` = `Cubic(0.32, 0.72, 0, 1)` |
| Reduced motion | `AnimationStyle.noAnimation` |

```dart
/* target */
import 'package:flutter/material.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';

Future<T?> showSacSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Color? backgroundColor,
  Color? barrierColor,
  bool isScrollControlled = false,
  bool isDismissible = true,
  bool enableDrag = true,
  bool useSafeArea = false,
  bool useRootNavigator = false,
  BoxConstraints? constraints,
  bool? showDragHandle,
  AnimationController? transitionAnimationController,
}) {
  final reduce = SacMotion.reduceMotionOf(context);
  return showModalBottomSheet<T>(
    context: context,
    builder: builder,
    backgroundColor: backgroundColor,
    barrierColor: barrierColor,
    isScrollControlled: isScrollControlled,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    useSafeArea: useSafeArea,
    useRootNavigator: useRootNavigator,
    constraints: constraints,
    showDragHandle: showDragHandle,
    transitionAnimationController: transitionAnimationController,
    sheetAnimationStyle: reduce
        ? AnimationStyle.noAnimation
        : const AnimationStyle(
            duration: SacMotion.modal,
            reverseDuration: SacMotion.routeExit,
            curve: SacMotion.drawer,
            reverseCurve: SacMotion.drawer,
          ),
  );
}
```

Forward every named argument the call site already passes. Do not add new defaults that change chrome (keep caller `backgroundColor`, `isDismissible`, etc.).

Export from `lib/core/widgets/sac_widgets.dart`.

Replace every live `showModalBottomSheet` in `lib/` with `showSacSheet`. After:

```text
rg 'showModalBottomSheet' lib --glob '*.dart'
```

must only hit `sac_sheet.dart` (the wrapper) and comments/docs.

Call-site files (complete list at `bff0a6bf`):

- `lib/core/widgets/section_switcher_sheet.dart`
- `lib/core/widgets/evidence_staging/image_source_dialog.dart`
- `lib/core/widgets/evidence_staging/upload_progress_sheet.dart`
- `lib/features/units/presentation/views/units_list_view.dart`
- `lib/features/units/presentation/views/unit_form_sheet.dart`
- `lib/features/units/presentation/views/unit_detail_view.dart`
- `lib/features/classes/presentation/views/class_counselor_assignments_view.dart`
- `lib/features/classes/presentation/views/classes_list_view.dart`
- `lib/features/classes/presentation/sheets/requirement_status_history_sheet.dart`
- `lib/features/activities/presentation/widgets/activity_form_widgets.dart`
- `lib/features/activities/presentation/widgets/activity_map_options_sheet.dart`
- `lib/features/notifications/presentation/widgets/notification_card.dart`
- `lib/features/settings/presentation/widgets/sync_cache_section.dart`
- `lib/features/settings/presentation/widgets/language_picker_tile.dart`
- `lib/features/evidence_folder/presentation/sheets/evidence_status_history_sheet.dart`
- `lib/features/achievements/presentation/views/achievements_view.dart`
- `lib/features/qr/presentation/views/qr_scanner_view.dart`
- `lib/features/master_honors/presentation/widgets/master_honor_roadmap_grid.dart`
- `lib/features/camporees/presentation/widgets/camporee_section_registration_sheet.dart`
- `lib/features/camporees/presentation/widgets/camporee_map_options_sheet.dart`
- `lib/features/camporees/presentation/views/camporee_register_member_view.dart`
- `lib/features/camporees/presentation/views/camporee_payments_view.dart`
- `lib/features/honors/presentation/views/honor_evidence_view.dart`
- `lib/features/honors/presentation/views/honor_requirements_view.dart`
- `lib/features/honors/presentation/views/honor_detail_view.dart`
- `lib/features/resources/presentation/widgets/resource_detail_sheet.dart`
- `lib/features/insurance/presentation/views/insurance_detail_view.dart`
- `lib/features/insurance/presentation/views/insurance_form_sheet.dart`
- `lib/features/insurance/presentation/views/insurance_view.dart`
- `lib/features/inventory/presentation/views/inventory_item_detail_view.dart`
- `lib/features/inventory/presentation/views/inventory_view.dart`
- `lib/features/inventory/presentation/views/add_inventory_item_sheet.dart`
- `lib/features/certificate_import/presentation/views/certificate_import_review_view.dart`
- `lib/features/support/presentation/views/report_problem_view.dart`
- `lib/features/monthly_reports/presentation/views/monthly_report_manual_data_form_view.dart`
- `lib/features/accessibility/presentation/views/accessibility_view.dart`
- `lib/features/profile/presentation/widgets/gender_selector.dart`
- `lib/features/profile/presentation/widgets/blood_type_selector.dart`
- `lib/features/post_registration/presentation/widgets/bottom_sheet_picker.dart`
- `lib/features/post_registration/presentation/views/allergies_selection_view.dart`
- `lib/features/post_registration/presentation/views/medicines_selection_view.dart`
- `lib/features/post_registration/presentation/views/add_edit_contact_view.dart`
- `lib/features/post_registration/presentation/views/diseases_selection_view.dart`
- `lib/features/members/presentation/widgets/members_filter_bar.dart`
- `lib/features/finances/presentation/views/finances_view.dart`
- `lib/features/finances/presentation/views/transaction_detail_view.dart`
- `lib/features/finances/presentation/views/add_transaction_sheet.dart`
- `lib/features/finances/presentation/views/all_transactions_view.dart`
- `lib/features/enrollment/presentation/views/enrollment_form_view.dart`

If `rg` finds another live call, migrate it too. If a listed line is gone, STOP and report that file.

On the camporee registration sheet: delete the local `sheetAnimationStyle` / `disableAnimations` block. `showSacSheet` owns that.

## Repo conventions to follow

- Tokens: `lib/core/animations/motion_tokens.dart`.
- Reduced-motion branch already proven: `camporee_section_registration_sheet.dart` `AnimationStyle.noAnimation`. Lift that into the helper; then that file uses the helper.
- Import: `package:sacdia_app/core/widgets/sac_sheet.dart` (or barrel `sac_widgets.dart`).
- Do not invent a custom `PageRoute` for sheets. `showModalBottomSheet` + `sheetAnimationStyle` is the Flutter API this repo already uses.

## Steps

1. Add `lib/core/widgets/sac_sheet.dart` exactly as Target.
2. Export it from `lib/core/widgets/sac_widgets.dart`.
3. Replace `showModalBottomSheet` → `showSacSheet` at every live call site. Keep generics (`showSacSheet<bool>`). Add the import.
4. Remove per-call `sheetAnimationStyle` (camporee registration). Do not leave a second style that fights the helper.
5. `rg` check in Target.

## Boundaries

- Do NOT restyle sheet chrome (radius, drag handle, colors).
- Do NOT change `isDismissible` / `enableDrag` / `isScrollControlled` at call sites.
- Do NOT replace `SacDialog` / `showDialog`.
- Do NOT add packages.
- Do NOT change go_router or `SacSlideUpRoute` pages (those are full-screen routes, not sheets).

## Verification

- **Mechanical**: `dart analyze lib/core/widgets/sac_sheet.dart`. `rg` check. No `flutter build`.
- **Feel check**:
  - Open section switcher, resource detail, language picker. Sheet rises with the iOS drawer curve, 240ms, starts moving immediately. Dismiss is 200ms, same curve.
  - Camporee registration sheet must feel identical to the others (no 200/180 leftover).
  - Slow Animations: no Material ease-in on the rise.
  - Reduce Motion: sheet appears/disappears with no slide (`AnimationStyle.noAnimation`).
- **Done when**: one helper owns sheet motion; zero live `showModalBottomSheet` outside `sac_sheet.dart`; camporee sheet uses the helper.
