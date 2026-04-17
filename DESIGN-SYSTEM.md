# SACDIA App - Design System & Style Guide (Flutter)

> This document describes what IS IMPLEMENTED in the codebase as of the audit date.
> Follow these patterns when adding new screens or widgets.
> Do NOT invent new patterns — if something is inconsistent across screens, this doc
> explicitly calls it out and recommends the canonical path.

> **Last audited: 2026-04-16**
> Design identity: "Scout Vibrante" — Duolingo gamification + Apple Health minimalism.
> White backgrounds, vibrant accents, progress as protagonist.

---

## 1. Stack

| Layer | Technology | Version |
|-------|-----------|---------|
| Framework | Flutter (Material 3) | ^3.6.1 SDK |
| State management | Riverpod | ^2.6.1 |
| Navigation | go_router | ^15.2.0 |
| HTTP | Dio | ^5.8.0+1 |
| Local storage | SharedPreferences + flutter_secure_storage | ^2.5.3 / ^9.2.4 |
| Icons | HugeIcons (stroke rounded) | ^1.1.5 |
| Charts | fl_chart | ^0.69.0 |
| Images | cached_network_image | ^3.4.1 |
| Animations | loading_animation_widget | ^1.3.0 |
| Maps | google_maps_flutter | ^2.10.0 |
| Push | firebase_messaging | ^15.1.6 |
| Architecture | Clean Architecture (domain / data / presentation) | - |

**Absolute rule**: All interactive widgets must come from the `core/widgets/` design system (`SacButton`, `SacCard`, `SacBadge`, `SacTextField`, `SacDialog`, `SacLoading`, `SacProgressBar`, `SacProgressRing`). Do not use raw Material widgets for interactive elements without a design system wrapper unless there is no Sac-prefixed equivalent.

---

## 2. Color Palette — "Scout Vibrante"

All colors are defined in `lib/core/theme/app_colors.dart`.

### 2.1 Brand Colors

| Token | Value | Role |
|-------|-------|------|
| `AppColors.primary` | `#F06151` | Primary actions, AppBar title, buttons, links, navigation |
| `AppColors.primaryLight` | `#FDE8E6` | Badges, chips, selection backgrounds, secondary button bg |
| `AppColors.primaryDark` | `#D94A3B` | Pressed states, secondary button text |
| `AppColors.primarySurface` | `#FFF1EF` | Very subtle selection tint |
| `AppColors.secondary` | `#4FBF9F` | Success, completed, progress, nature/scout |
| `AppColors.secondaryLight` | `#E0F5EF` | Success badge background |
| `AppColors.secondaryDark` | `#2D8A70` | Success text |
| `AppColors.accent` | `#FBBD5E` | Stars, achievements, rewards, in-progress |
| `AppColors.accentLight` | `#FFF4E0` | In-progress badge background |
| `AppColors.accentDark` | `#B8862B` | Warning text |
| `AppColors.error` | `#DC2626` | Errors, destructive actions (differentiated from primary) |
| `AppColors.errorLight` | `#FEE2E2` | Error badge background |
| `AppColors.errorDark` | `#991B1B` | Error text |

### 2.2 Surface Tokens — Light Mode

| Token | Value | Role |
|-------|-------|------|
| `AppColors.lightBackground` | `#FFFFFF` | Main scaffold background |
| `AppColors.lightSurface` | `#FFFFFF` | Cards, modals, bottom sheets |
| `AppColors.lightSurfaceVariant` | `#F8FAFC` | Alternate sections, secondary backgrounds |
| `AppColors.lightBorder` | `#E2E8F0` | Card borders, dividers |
| `AppColors.lightBorderLight` | `#F1F5F9` | Very subtle separators |
| `AppColors.lightDivider` | `#E2E8F0` | Divider alias |

### 2.3 Text Tokens — Light Mode

| Token | Value | Role |
|-------|-------|------|
| `AppColors.lightText` | `#0F172A` | Titles, primary text |
| `AppColors.lightTextSecondary` | `#64748B` | Subtitles, descriptions |
| `AppColors.lightTextTertiary` | `#94A3B8` | Placeholders, hints, metadata |

### 2.4 Surface Tokens — Dark Mode (OLED-optimized, no blue undertone)

| Token | Value | Role |
|-------|-------|------|
| `AppColors.darkBackground` | `#000000` | Main scaffold background (true black OLED) |
| `AppColors.darkSurface` | `#1A1A1A` | Cards, modals — elevation 1dp |
| `AppColors.darkSurfaceVariant` | `#252525` | Alternate sections — elevation 2dp |
| `AppColors.darkBorder` | `#303030` | Borders, subtle neutral |
| `AppColors.darkDivider` | `#303030` | Divider alias |

### 2.5 Text Tokens — Dark Mode

| Token | Value | Role |
|-------|-------|------|
| `AppColors.darkText` | `#F2F2F2` | Primary text (soft white, less eye strain) |
| `AppColors.darkTextSecondary` | `#8C8C8C` | Secondary text (neutral grey, no blue tint) |
| `AppColors.darkTextTertiary` | `#5C5C5C` | Hints, metadata |

### 2.6 Semantic State Aliases

Raw aliases in `AppColors` (light-only — do NOT use directly in widget paint code):

```dart
AppColors.success  = AppColors.secondary  (#4FBF9F)
AppColors.warning  = AppColors.accent     (#FBBD5E)
AppColors.info     = AppColors.sacBlue    (#2EA0DA)
AppColors.error    = Color(0xFFDC2626)
```

Use `context.sac.*` getters instead — see §2.7.

### 2.7 Dark-Mode Aware Color Resolution — MANDATED PATTERN

**`context.sac` (the `SacColors` extension on `BuildContext`) is the MANDATED pattern for all color access in widget paint code.**

NEVER use `AppColors.*` directly in widget paint code. `AppColors` constants are light-mode values and do not adapt to dark mode. The `SacColors` extension resolves the correct variant automatically based on `Theme.of(context).brightness`.

```dart
// File: lib/core/theme/sac_colors.dart
final c = context.sac;

// Surfaces
c.background      // white / #000000 (true black OLED)
c.surface         // white / #1A1A1A
c.surfaceVariant  // #F8FAFC / #252525
c.border          // #E2E8F0 / #303030
c.divider         // alias for border
c.borderLight     // #F1F5F9 / #252525
c.shadow          // rgba(0,0,0,0.08) / rgba(255,255,255,0.04)

// Text
c.text            // #0F172A / #F2F2F2
c.textSecondary   // #64748B / #8C8C8C
c.textTertiary    // #94A3B8 / #5C5C5C

// On-surface
c.onPrimary       // Colors.white (both modes)
c.barrierColor    // rgba(0,0,0,0.5) / rgba(0,0,0,0.7)

// Semantic state (added — same Color value both modes, use these over AppColors.*)
c.success         // #4FBF9F
c.onSuccess       // Colors.white
c.warning         // #FBBD5E
c.onWarning       // #B8862B (dark text on yellow)
c.info            // #2EA0DA
c.onInfo          // Colors.white
c.error           // #DC2626
c.onError         // Colors.white
```

**Known tech-debt — 83-file migration pending:**
As of 2026-04-16, approximately 83 widget files use `AppColors.error` / `AppColors.success` / `AppColors.warning` or hardcoded `Color(0xFF…)` directly in paint code, bypassing `context.sac`. This is a known violation. Future agents: do NOT add more `AppColors.*` calls in paint code — use `context.sac.*`. The migration of existing files is tracked as a separate task.

### 2.8 Class-Specific Colors (Scout tradition — do NOT change)

Aventureros classes, Conquistadores classes, and Guias Mayores classes each have
dedicated brand colors stored in `AppColors`. Resolved via:

```dart
AppColors.classColor(String className)    // returns Color
AppColors.classLogoAsset(String className) // returns asset path or null
```

See `lib/core/theme/app_colors.dart` lines 171–258 for the full maps.

### 2.9 Honor Category Colors

9 categories each with a distinct color (catAdra, catagropecuarias, catCienciasSalud, etc.).
Used in honor list and catalog views. Full list in `AppColors` lines 199–209.

### 2.10 Status Badge — Info / Sent (dark-mode aware hardcoded)

```dart
AppColors.statusInfoBgLight  = #EFF6FF   // light badge bg
AppColors.statusInfoBgDark   = #1E293B   // dark badge bg
AppColors.statusInfoText     = #1D4ED8   // light badge text
AppColors.statusInfoTextDark = #60A5FA   // dark badge text
```

These are the only hardcoded non-semantic colors allowed for badges — they exist
because the semantic `info` token does not map cleanly to the correct hue for "sent" status.

---

## 3. Typography

### 3.1 Font Family

```dart
fontFamily: '.SF Pro Text'
```

SF Pro Text is native on iOS. Falls back gracefully to the system font on Android.
No custom font files are bundled. No Google Fonts dependency.

### 3.2 Type Scale (Material 3 TextTheme)

| Style | Size | Weight | Color (light) | Role |
|-------|------|--------|---------------|------|
| `displayLarge` | 32px | w700 | lightText | Hero headers, splash |
| `displayMedium` | 28px | w700 | lightText | Screen main title |
| `displaySmall` | 24px | w700 | lightText | Section title |
| `headlineLarge` | 22px | w600 | lightText | Section headers |
| `headlineMedium` | 20px | w600 | lightText | Card headers |
| `headlineSmall` | 18px | w600 | lightText | Sub-section headers |
| `titleLarge` | 18px | w500 | lightText | Card titles |
| `titleMedium` | 16px | w500 | lightText | List item titles |
| `titleSmall` | 14px | w500 | lightText | Compact titles |
| `bodyLarge` | 16px | w400 | lightText | Primary body, height 1.5 |
| `bodyMedium` | 14px | w400 | lightText | Standard body, height 1.5 |
| `bodySmall` | 12px | w400 | lightTextSecondary | Metadata, height 1.5 |
| `labelLarge` | 14px | w600 | lightText | Buttons, badges |
| `labelMedium` | 12px | w500 | lightTextSecondary | Chips, secondary labels |
| `labelSmall` | 10px | w500 | lightTextTertiary | Micro labels, footnotes |

### 3.3 Typography Rules

- AppBar titles: `fontSize: 20, fontWeight: w700, color: AppColors.primary`
- Prefer `Theme.of(context).textTheme.{style}` over hardcoded `TextStyle`
- Use `.copyWith()` only for overrides (color, weight changes)
- `letterSpacing: -0.5` on display sizes for tighter look

---

## 4. Spacing and Radius

### 4.1 Radius Scale

```dart
// lib/core/theme/app_theme.dart
AppTheme.radiusXS   = 8.0    // micro elements
AppTheme.radiusSM   = 12.0   // inputs, buttons, list tiles
AppTheme.radiusMD   = 16.0   // cards (main card radius)
AppTheme.radiusLG   = 20.0   // bottom sheets (vertical top only), chips
AppTheme.radiusXL   = 24.0   // large containers
AppTheme.radiusFull = 100.0  // pills, FABs, avatars
```

### 4.2 Standard Spacing

| Context | Value | Notes |
|---------|-------|-------|
| Screen horizontal padding | Resolved via `Responsive.horizontalPadding(context)` | Adapts to screen width |
| Card padding | `EdgeInsets.all(16)` | `SacCard` default |
| List tile padding | `EdgeInsets.symmetric(horizontal: 16, vertical: 4)` | `listTileTheme` |
| Input padding | `EdgeInsets.symmetric(horizontal: 16, vertical: 14)` | `inputDecorationTheme` |
| Button padding small | `EdgeInsets.symmetric(horizontal: 16, vertical: 8)` | `SacButtonSize.small` |
| Button padding medium | `EdgeInsets.symmetric(horizontal: 24, vertical: 14)` | `SacButtonSize.medium` |
| Button padding large | `EdgeInsets.symmetric(horizontal: 32, vertical: 18)` | `SacButtonSize.large` |

### 4.3 Responsive Utilities

```dart
// lib/core/utils/responsive.dart
Responsive.isCompact(context)   // < 600dp
Responsive.isMedium(context)    // 600-840dp
Responsive.isExpanded(context)  // >= 840dp
Responsive.horizontalPadding(context) // resolves to appropriate h-padding
```

---

## 5. Icon System

### 5.1 Primary Icon Library: HugeIcons

All icons use `hugeicons: ^1.1.5` with the stroke-rounded style.

```dart
import 'package:hugeicons/hugeicons.dart';

HugeIcon(
  icon: HugeIcons.strokeRoundedHome01,
  size: 24,
  color: AppColors.primary,
)
```

### 5.2 HugeIconData Typedef (CRITICAL)

HugeIcons constants are `List<List<dynamic>>` internally. Always declare icon
fields in widgets using the `HugeIconData` typedef to avoid compile errors.

```dart
// File: lib/core/utils/icon_helper.dart
typedef HugeIconData = List<List<dynamic>>;
```

**Rule**: If your widget ONLY accepts HugeIcons, declare the field as `HugeIconData`:
```dart
import 'package:sacdia_app/core/utils/icon_helper.dart';

class MyWidget extends StatelessWidget {
  final HugeIconData icon;   // CORRECT
  // final dynamic icon;     // WRONG — causes type errors at runtime
  // final IconData icon;    // WRONG — incompatible type
}
```

**Exception**: Widgets that accept BOTH Material `IconData` AND `HugeIconData`
(e.g. `SacButton`, `SacBadge`, `DashboardCard`) keep `dynamic` and dispatch
via `buildIcon()`:

```dart
// lib/core/utils/icon_helper.dart
Widget buildIcon(dynamic icon, {double size = 24, Color? color}) {
  if (icon is IconData) return Icon(icon, size: size, color: color);
  return HugeIcon(icon: icon, size: size, color: color ?? Colors.black);
}
```

### 5.3 Standard Icon Sizes

| Context | Size |
|---------|------|
| Navigation bar | 24px |
| Button icon | 16px (small) / 20px (medium) / 24px (large) |
| Badge icon | 14px |
| Card header | 20–24px |
| Empty state | 48–56px |
| AppBar actions | 24px |

---

## 6. Core Widget Library (`lib/core/widgets/`)

### 6.1 SacButton

**File:** `lib/core/widgets/sac_button.dart`

The primary button widget. Wraps `ElevatedButton` or `TextButton` with scale
press animation (0.96) and haptic feedback.

**Variants (`SacButtonVariant`):**

| Variant | Background | Foreground | Border |
|---------|-----------|-----------|--------|
| `primary` | `AppColors.primary` | white | none |
| `secondary` | `AppColors.primaryLight` | `AppColors.primaryDark` | none |
| `outline` | transparent | `AppColors.primary` | `AppColors.primary 1.5px` |
| `ghost` | transparent | `AppColors.primary` | none (TextButton) |
| `destructive` | `AppColors.error` | white | none |
| `success` | `AppColors.secondary` | white | none |

**Sizes (`SacButtonSize`):**

| Size | Min height | Padding | Font |
|------|-----------|---------|------|
| `small` | 36px | h:8 v:16 | 13px |
| `medium` | 48px | h:14 v:24 | 16px |
| `large` | 56px | h:18 v:32 | 18px |

**Named constructors (shortcuts):**
- `SacButton.primary({...})` — primary + fullWidth:true
- `SacButton.outline({...})` — outline + fullWidth:true
- `SacButton.ghost({...})` — ghost + fullWidth:false
- `SacButton.destructive({...})` — destructive + fullWidth:true
- `SacButton.success({...})` — success + fullWidth:true

**Icon support:** `icon` and `trailingIcon` accept `dynamic` (dispatched via `buildIcon()`).

**Disabled state:** resolved via `context.sac` tokens — disabled uses `surface` bg + `textTertiary` fg.

```dart
SacButton(
  text: 'Guardar',
  variant: SacButtonVariant.primary,
  size: SacButtonSize.medium,
  icon: HugeIcons.strokeRoundedCheckmarkCircle01,
  isLoading: _isSaving,
  onPressed: _handleSave,
)

// Full-width primary (most common)
SacButton.primary(
  text: 'Continuar',
  onPressed: _next,
)
```

### 6.2 SacBadge

**File:** `lib/core/widgets/sac_badge.dart`

Pill-shaped label for statuses, categories, and counts.

**Variants (`SacBadgeVariant`):**

| Variant | Background | Foreground |
|---------|-----------|-----------|
| `primary` | `primaryLight` | `primaryDark` |
| `secondary` (success shortcut) | `secondaryLight` | `secondaryDark` |
| `accent` (warning shortcut) | `accentLight` | `accentDark` |
| `error` | `errorLight` | `errorDark` |
| `neutral` | `context.sac.surfaceVariant` | `context.sac.textSecondary` |

**Named constructors:**
- `SacBadge.success(label:)` — maps to `secondary` variant
- `SacBadge.warning(label:)` — maps to `accent` variant
- `SacBadge.error(label:)` — maps to `error` variant

Icon: `dynamic` field dispatched via `buildIcon()` at 14px.
Border radius: 20px (pill).
Text: `fontSize: 12, fontWeight: w500`.

```dart
SacBadge(label: 'Activo', variant: SacBadgeVariant.secondary)
SacBadge.error(label: 'Error', icon: HugeIcons.strokeRoundedAlertCircle)
```

### 6.3 SacCard

**File:** `lib/core/widgets/sac_card.dart`

The standard card container. White/dark surface, `lightBorder`, subtle shadow (`blurRadius: 8, offset: (0,2)`), `radiusMD` (16px).

**Props:**

| Prop | Type | Default | Notes |
|------|------|---------|-------|
| `child` | Widget | required | Card content |
| `onTap` | VoidCallback? | null | If set, wraps in Material+InkWell |
| `padding` | EdgeInsetsGeometry | `all(16)` | Internal padding |
| `margin` | EdgeInsetsGeometry | `zero` | External margin |
| `borderColor` | Color? | `c.border` | Override border color |
| `accentColor` | Color? | null | 4px left accent bar (Google Classroom style) |
| `backgroundColor` | Color? | `c.surface` | Override background |
| `animate` | bool | false | Fade + scale entrance on mount |
| `animationDelay` | Duration | zero | Stagger delay for entrance animation |

```dart
// Standard card
SacCard(
  child: MyContent(),
)

// Tappable card
SacCard(
  onTap: () => context.push('/detail'),
  child: MyContent(),
)

// With class accent color (list items)
SacCard(
  accentColor: AppColors.classColor('Amigo'),
  child: MyContent(),
)

// With stagger entrance animation
SacCard(
  animate: true,
  animationDelay: Duration(milliseconds: index * 80),
  child: MyContent(),
)
```

### 6.4 SacTextField

**File:** `lib/core/widgets/sac_text_field.dart`

Styled text input wrapping Flutter's `TextFormField` with theme-aware decoration.

**Key props:**

| Prop | Notes |
|------|-------|
| `label` | Floating label |
| `hint` | Placeholder text |
| `prefixIcon` | `dynamic` (HugeIcon or IconData) |
| `suffix` | `Widget?` for trailing action (e.g. eye icon for password) |
| `obscureText` | Auto-adds eye-toggle suffix |
| `validator` | Standard `String? Function(String?)` |
| `autovalidateMode` | Default: `AutovalidateMode.disabled` |
| `maxLines` | Default 1; multiline text areas use > 1 |

Decoration from `InputDecorationTheme`: radius 12px, filled white/dark surface,
primary border on focus (2px), error border on error (1.5px → 2px).

```dart
SacTextField(
  label: 'Email',
  hint: 'tu@email.com',
  keyboardType: TextInputType.emailAddress,
  prefixIcon: HugeIcons.strokeRoundedMail01,
  validator: Validators.email,
  controller: _emailController,
)

SacTextField(
  label: 'Contraseña',
  obscureText: true,  // auto-adds eye toggle
  validator: Validators.required,
)
```

### 6.5 SacDialog

**File:** `lib/core/widgets/sac_dialog.dart`

iOS-inspired dialog. Rounded 20px, surface bg, title in `AppColors.primary`,
iOS-style horizontal action buttons separated by 0.5px dividers.
Scale + fade entrance animation (220ms, `Curves.easeOutBack`).

**Use the static helper for confirm/cancel pattern:**

```dart
final confirmed = await SacDialog.show(
  context,
  title: 'Eliminar contacto',
  content: '¿Estás seguro?',
  confirmLabel: 'Eliminar',
  cancelLabel: 'Cancelar',
  confirmIsDestructive: true,  // uses AppColors.error
);
if (confirmed == true) { ... }
```

**Action styles (`SacDialogActionStyle`):**

| Style | Color | Weight |
|-------|-------|--------|
| `confirm` | `AppColors.primary` | w600 |
| `destructive` | `AppColors.error` | w600 |
| `cancel` | `context.sac.textSecondary` | w400 |

### 6.6 SacLoading / SacLoadingSmall

**File:** `lib/core/widgets/sac_loading.dart`

Primary loading indicator: animated wave dots (`loading_animation_widget`).

```dart
// Full screen loading
Center(child: SacLoading())

// Custom color
SacLoading(color: AppColors.secondary)

// Compact (same animation — both render 30px wave dots)
SacLoadingSmall()
```

Standard loading pattern for screen-level loads:
```dart
// In an AsyncValue.when():
loading: () => const Center(child: SacLoading()),
```

### 6.7 SacProgressBar

**File:** `lib/core/widgets/sac_progress_bar.dart`

Animated linear progress bar. Fills from 0 to `progress` on mount with
`Curves.easeOutCubic` over 700ms. One shimmer sweep after fill.

```dart
SacProgressBar(
  progress: 0.75,           // 0.0 to 1.0
  height: 6.0,              // default
  useGradient: true,        // primary -> secondary gradient (default)
  label: '75%',             // optional right label
  showPercentage: false,    // optional bottom percentage
)
```

- Gradient: `AppColors.primary` → `AppColors.secondary` (left to right)
- Track: `context.sac.borderLight`
- `showShimmer: true` (default) — disable for repeated updates

### 6.8 SacProgressRing

**File:** `lib/core/widgets/sac_progress_ring.dart`

Animated ring progress indicator. Apple Health / Fitness style.
Sweep gradient (`primary` → secondary). Rounded stroke caps.
Spring-like fill animation (900ms, `Curves.easeOutCubic`).

```dart
SacProgressRing(
  progress: 0.6,       // 0.0 to 1.0
  size: 120,           // diameter
  strokeWidth: 8,
  child: Text('60%'),  // optional center widget
)
```

### 6.9 Other Widgets in core/widgets/

| Widget | File | Purpose |
|--------|------|---------|
| `SacDropdownField` | `sac_dropdown_field.dart` | Themed dropdown with label |
| `SacImageViewer` | `sac_image_viewer.dart` | Full-screen image viewer with zoom |
| `SacPdfViewer` | `sac_pdf_viewer.dart` | In-app PDF viewer |
| `SectionSwitcherSheet` | `section_switcher_sheet.dart` | Bottom sheet for club section switching |

### 6.10 Barrel File — sac_widgets.dart

**File:** `lib/core/widgets/sac_widgets.dart`

Single-import barrel for the entire design system widget set:

```dart
import 'package:sacdia_app/core/widgets/sac_widgets.dart';
```

**Exported widgets (complete list):**

| Export | Widget(s) |
|--------|-----------|
| `sac_badge.dart` | `SacBadge`, `SacBadgeVariant` |
| `sac_button.dart` | `SacButton`, `SacButtonVariant`, `SacButtonSize` |
| `sac_card.dart` | `SacCard` |
| `sac_dialog.dart` | `SacDialog`, `SacDialogActionStyle` |
| `sac_dropdown_field.dart` | `SacDropdownField` |
| `sac_loading.dart` | `SacLoading`, `SacLoadingSmall` |
| `sac_pdf_viewer.dart` | `SacPdfViewer` |
| `sac_progress_bar.dart` | `SacProgressBar` |
| `sac_progress_ring.dart` | `SacProgressRing` |
| `sac_text_field.dart` | `SacTextField` |
| `section_switcher_sheet.dart` | `SectionSwitcherSheet` |

**NOT in barrel (intentional):**
- `sac_image_viewer.dart` — `SacImageViewer` is launched via `Navigator.push` with its own routing context; it is not a composable widget for embedding.

### 6.11 Legacy Widgets — Deprecated

The following widgets are deprecated and must NOT be used in new code:

| Deprecated | Canonical replacement | Prop mapping |
|------------|----------------------|-------------|
| `CustomButton` (`custom_button.dart`) | `SacButton` (`sac_widgets.dart`) | `text` → `text`, `onPressed` → `onPressed`, `isLoading` → `isLoading`, `backgroundColor` → use `variant` |
| `CustomTextField` (`custom_text_field.dart`) | `SacTextField` (`sac_widgets.dart`) | `controller` → `controller`, `labelText` → `label`, `hintText` → `hint`, `validator` → `validator`, `prefixIcon` → `prefixIcon` |

Both classes are annotated with `@Deprecated(...)` at the class level. The Dart analyzer will emit warnings in any file that references them. Do not suppress those warnings — they are intentional signals to migrate.

**Migration — existing consumers:** There are existing callers of `CustomButton` and `CustomTextField` throughout the codebase. Do NOT mass-migrate them in a single commit — migrate per feature/screen as part of normal development. The `@Deprecated` annotation is the tracking mechanism.

---

## 7. Theme Configuration

### 7.1 ThemeData Setup

**Files:**
- `lib/core/theme/app_theme.dart` — `AppTheme.lightTheme` and `AppTheme.darkTheme`
- `lib/core/theme/app_colors.dart` — all color constants
- `lib/core/theme/sac_colors.dart` — `SacColors` extension on `BuildContext`
- `lib/core/theme/theme_provider.dart` — Riverpod `ThemeNotifier`

**Material 3 is enabled** (`useMaterial3: true`).

**Component themes configured globally** (do not override in individual screens):
- `AppBarTheme`: white/black bg, elevation 0, `scrolledUnderElevation: 0.5`, `centerTitle: false`, title in `AppColors.primary` w700
- `CardTheme`: surface bg, elevation 0, radiusMD with border
- `ElevatedButtonTheme`: primary bg, white fg, 0 elevation, radiusSM, h:48
- `OutlinedButtonTheme`: primary fg/border, radiusSM, h:48
- `TextButtonTheme`: primary fg, radiusSM
- `FilledButtonTheme`: primary bg, white fg, radiusSM
- `InputDecorationTheme`: filled, surface fill, radiusSM borders, primary focus
- `ChipTheme`: surfaceVariant bg, primaryLight selected, radiusLG
- `DividerTheme`: 1px, space 1
- `BottomNavigationBarTheme`: surface bg, primary selected, elevation 0
- `NavigationBarTheme`: surface bg, primaryLight indicator (dark: primaryDark), elevation 0
- `SnackBarTheme`: floating, radiusSM, inverted colors
- `DialogTheme`: surface bg, radiusMD, headlineSmall text style
- `BottomSheetTheme`: surface bg, top-only radius 20px
- `ListTileTheme`: radiusSM, h:4 v:16 padding
- `SwitchTheme`: primary track when selected
- `CheckboxTheme`: primary fill when selected, radiusXS (4px), 1.5px border
- `FloatingActionButtonTheme`: primary bg, white fg, elevation 2, circle
- `ProgressIndicatorTheme`: primary color, borderLight track

### 7.2 Theme Persistence

The `ThemeNotifier` persists the user's theme preference in `SharedPreferences`
using key `AppConstants.themeKey`. Defaults to `ThemeMode.system`.

```dart
// Toggle theme
ref.read(themeNotifierProvider.notifier).toggleTheme();

// Set explicit theme
ref.read(themeNotifierProvider.notifier).setDarkTheme();
ref.read(themeNotifierProvider.notifier).setSystemTheme();
```

---

## 8. Navigation

### 8.1 Router

**File:** `lib/core/config/router.dart`

Navigation uses `go_router ^15.2.0`. All routes are declarative. The router
contains redirect guards based on auth state (from `authNotifierProvider`).

**Route names** are constants in `lib/core/config/route_names.dart`.

### 8.2 Shell / Bottom Navigation

The main shell is rendered inside `DashboardView` and uses `BottomNavigationBar`
(Material 2 style) or `NavigationBar` (M3). The actual implementation uses the
bottom nav theme configured in `AppTheme`.

Tab bar items navigate via `context.go(RouteName)`.

### 8.3 Page Transitions

**File:** `lib/core/animations/page_transitions.dart`

Three standard transitions registered in the router:

| Transition | Function | Duration | Use case |
|------------|----------|----------|---------|
| Shared-axis (horizontal slide) | `sharedAxisPage<T>()` | 340ms forward / 280ms back | Standard forward/back navigation |
| Fade-through | `fadeThroughPage<T>()` | ~300ms | Tab switches, peer-level navigation |
| Slide-up | `slideUpPage<T>()` | ~300ms | Bottom sheet as page, modal flows |

All transitions respect `MediaQuery.disableAnimations`.

The router wraps most routes with `_sharedAxisBuild` (shared-axis slide).

### 8.4 Post-Registration Shell

Multi-step onboarding flow wrapped in `PostRegistrationShell`.
Uses a linear `PageView`-style progression. Steps live in
`lib/features/post_registration/presentation/views/`.

---

## 9. State Management (Riverpod)

### 9.1 Pattern

All features use `flutter_riverpod: ^2.6.1`.

| Notifier type | When to use |
|---------------|------------|
| `AsyncNotifier<T>` | Async data that can be in loading/error/data state |
| `Notifier<T>` | Sync state with methods |
| `NotifierProvider` | Standard provider for notifiers |
| `AsyncNotifierProvider` | Standard provider for async notifiers |

Widgets consume providers using `ConsumerWidget` or `ConsumerStatefulWidget`.
Use `ref.watch()` for reactive data, `ref.read()` in event handlers.

### 9.2 Feature Provider Pattern

Each feature has its own `providers/` folder:
```
features/{feature}/presentation/providers/{feature}_providers.dart
```

### 9.3 Global Providers

| Provider | File | Role |
|---------|------|------|
| `authNotifierProvider` | `features/auth/presentation/providers/auth_providers.dart` | Auth state, user, JWT |
| `themeNotifierProvider` | `core/theme/theme_provider.dart` | Theme mode |
| `sharedPreferencesProvider` | `providers/storage_provider.dart` | SharedPreferences instance |
| `appBootstrapProvider` | `core/providers/app_bootstrap_provider.dart` | App init sequence |

---

## 10. Form Patterns

### 10.1 Standard Form

```dart
final _formKey = GlobalKey<FormState>();

Form(
  key: _formKey,
  child: Column(
    children: [
      SacTextField(
        label: 'Nombre',
        validator: (v) => v?.isEmpty == true ? 'Requerido' : null,
        controller: _nameController,
      ),
      const SizedBox(height: 16),
      SacButton.primary(
        text: 'Guardar',
        isLoading: _isLoading,
        onPressed: _submit,
      ),
    ],
  ),
)

void _submit() {
  if (!_formKey.currentState!.validate()) return;
  // proceed
}
```

### 10.2 Validation

Common validators in `lib/core/utils/validators.dart`.
Always validate on both client and server.
`autovalidateMode: AutovalidateMode.onUserInteraction` is preferred for forms
where the user has already attempted to submit.

### 10.3 Multi-Step Forms (Post-Registration)

Each step is a separate `View` widget. A shell widget (`PostRegistrationShell`)
manages progression. Steps do NOT share a single form key — each step validates
independently before advancing.

---

## 11. Loading, Empty, and Error States

### 11.1 Loading (screen-level)

```dart
// In AsyncValue.when():
loading: () => const Scaffold(
  body: Center(child: SacLoading()),
),
```

### 11.2 Empty State

No shared `EmptyState` widget exists in `core/widgets/`. Feature screens implement
their own inline empty states, typically:

```dart
// Pattern A (most common — icon + text centered)
Center(
  child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      HugeIcon(
        icon: HugeIcons.strokeRoundedInbox01,
        size: 56,
        color: c.textTertiary,
      ),
      const SizedBox(height: 12),
      Text(
        'Sin registros',
        style: TextStyle(fontSize: 16, color: c.textSecondary),
      ),
    ],
  ),
)
```

**Note**: pattern is inconsistent across features. Pattern A (above) is used in the
majority of screens (dashboard, units). If adding a new screen, use Pattern A.

### 11.3 Error State

```dart
// In AsyncValue.when():
error: (e, _) => Center(
  child: Text(
    e.toString(),
    style: TextStyle(color: context.sac.error), // use sac token, not AppColors.error
  ),
),
```

### 11.4 Pull-to-Refresh

```dart
RefreshIndicator(
  color: AppColors.primary,
  onRefresh: () async {
    await ref.read(myProvider.notifier).refresh();
  },
  child: ListView(...),
)
```

Always use `AlwaysScrollableScrollPhysics()` on the inner scroll view so
pull-to-refresh works even when content is shorter than the screen.

---

## 12. Screen Archetypes

### 12.1 List / Index Screen

**Examples:**
- `lib/features/classes/presentation/views/classes_list_view.dart`
- `lib/features/units/presentation/views/units_list_view.dart`
- `lib/features/honors/presentation/views/honors_catalog_view.dart`

**Pattern:**
```
Scaffold
  AppBar (or custom header in SafeArea)
  body: RefreshIndicator
    SingleChildScrollView / ListView.builder
      Column / cards
```

Units list has auto-navigate logic: if user has exactly ONE visible unit,
it navigates directly to detail (post-frame callback).

### 12.2 Detail Screen

**Examples:**
- `lib/features/classes/presentation/views/class_detail_with_progress_view.dart`
- `lib/features/club/presentation/views/club_detail_view.dart`
- `lib/features/camporees/presentation/views/camporee_detail_view.dart`

**Pattern:**
```
Scaffold
  CustomScrollView or SingleChildScrollView
    SliverAppBar (optional hero image) or standard AppBar
    SacCard sections
    SacProgressBar / SacProgressRing for progress data
```

### 12.3 Form Screen

**Examples:**
- `lib/features/enrollment/presentation/views/enrollment_form_view.dart`
- `lib/features/activities/presentation/views/create_activity_view.dart`
- `lib/features/units/presentation/views/unit_form_sheet.dart`

**Pattern:**
```
Scaffold
  AppBar (back button + title)
  SingleChildScrollView
    Padding (horizontal: screen padding)
      Form
        SacTextField fields
        SacDropdownField for selects
        SacButton.primary for submit
```

### 12.4 Modal / Bottom Sheet

**Examples:**
- `lib/features/units/presentation/views/unit_form_sheet.dart`
- `lib/features/achievements/presentation/views/achievement_detail_sheet.dart`
- `lib/core/widgets/section_switcher_sheet.dart`

**Pattern:**
```dart
showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  builder: (ctx) => DraggableScrollableSheet(
    initialChildSize: 0.7,
    maxChildSize: 0.95,
    builder: (_, controller) => Container(
      decoration: BoxDecoration(
        color: context.sac.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: content,
    ),
  ),
)
```

Bottom sheet radius is always `top: Radius.circular(20)` (from `BottomSheetTheme`).

### 12.5 Auth Screens

**Examples:**
- `lib/features/auth/presentation/views/login_view.dart`
- `lib/features/auth/presentation/views/register_view.dart`
- `lib/features/auth/presentation/views/forgot_password_view.dart`
- `lib/features/auth/presentation/views/splash_view.dart`

**Login pattern:**
- White background (`lightBackground`)
- SVG logo at top
- `SacCard` wrapping the form (clean separation)
- `SacTextField` for email/password
- Rate limiting: 3 failed attempts → 30s cooldown with countdown display
- `SacButton.primary` for submit

### 12.6 Onboarding / Post-Registration

**Examples:**
- `lib/features/post_registration/presentation/views/post_registration_shell.dart`
- `lib/features/post_registration/presentation/views/personal_info_step_view.dart`
- `lib/features/post_registration/presentation/views/photo_step_view.dart`

Multi-step linear flow. Each step is a separate view file. Shell manages step index.
Progress shown as linear indicator at the top of the shell.

### 12.7 Dashboard

**File:** `lib/features/dashboard/presentation/views/dashboard_view.dart`

No AppBar — uses `SafeArea` + `SingleChildScrollView` with `RefreshIndicator`.
Contains composable widgets: `WelcomeHeader`, `ClubInfoCard`, `CurrentClassCard`,
`QuickAccessGrid`, `QuickStatsCard`, `UpcomingActivitiesCard`,
`MembershipStatusBanner`.

Widget files in `lib/features/dashboard/presentation/widgets/`.

---

## 13. RBAC-Aware UI

### 13.1 Role Permissions (Units feature as reference)

```dart
// Pattern used in units_list_view.dart
const _kManagementRoles = [
  'director', 'sub_director', 'secretario', 'secretario_tesorero',
];

bool _canManageRole(String? role) =>
    _kManagementRoles.contains(role?.trim().toLowerCase());

bool _canDeleteRole(String? role) =>
    role?.trim().toLowerCase() == 'director';
```

| Role | See all units | Create/Edit | Delete (soft) | Register points |
|------|--------------|-------------|---------------|-----------------|
| `director` | yes | yes | yes | yes |
| `sub_director` | yes | yes | no | yes |
| `secretario` | yes | yes | no | yes |
| `secretario_tesorero` | yes | yes | no | yes |
| `consejero` | own only | no | no | yes |
| `capitan_unidad` | own only | no | no | yes |
| `secretario_unidad` | own only | no | no | yes |

### 13.2 How to Gate UI

```dart
// FAB / create button — management roles only
if (_canManageRole(userRole))
  FloatingActionButton(
    onPressed: () => _openCreateSheet(),
    child: const Icon(Icons.add),
  ),

// Filter visible items by role
final visibleUnits = _filterUnitsByRole(allUnits, userRole, userId);

// Delete option — directors only
if (_canDeleteRole(userRole))
  SacButton.destructive(text: 'Eliminar', onPressed: _delete),
```

### 13.3 Club Context

Role resolution uses `ClubContext` (provider `clubContextProvider` or similar).
For multi-section directors, activities have a "conjunta" (joint) mode —
see `lib/features/activities/` for the implementation.

---

## 14. Animation Conventions

### 14.1 Card Entrance (Stagger)

```dart
// Stagger a list of cards manually
SacCard(
  animate: true,
  animationDelay: Duration(milliseconds: index * 80),
  child: ...,
)
```

### 14.2 Staggered List Animation

**File:** `lib/core/animations/staggered_list_animation.dart`

Use `StaggeredListAnimation` wrapper for lists that should animate items in sequence.

### 14.3 Page Transitions

Use `sharedAxisPage`, `fadeThroughPage`, or `slideUpPage` in the router
(section 8.3). Never define custom `PageRoute` classes outside `page_transitions.dart`.

### 14.4 Scale Press on Buttons

`SacButton` applies `ScaleTransition(scale: 0.96)` on `TapDown` with
`HapticFeedback.lightImpact()`. Do NOT add redundant `GestureDetector` wrappers
around `SacButton` — the animation is already built in.

### 14.5 Celebration Overlay

**File:** `lib/core/animations/celebration_overlay.dart`

Used for achievement unlocks and gamification moments. Renders over the screen.

### 14.6 Animated Counter

**File:** `lib/core/animations/animated_counter.dart`

Animates a numeric value from old to new over a duration. Use for KPI cards and
score displays.

---

## 15. File and Folder Conventions

### 15.1 Feature Folder Structure

```
lib/features/{feature}/
├── data/
│   ├── datasources/    # API calls (Dio), local (Hive/SharedPrefs)
│   ├── models/         # JSON-serializable models (Freezed)
│   └── repositories/   # Implements domain interfaces
├── domain/
│   ├── entities/       # Pure Dart classes (no serialization)
│   ├── repositories/   # Abstract interfaces
│   └── usecases/       # Single-responsibility use case classes
└── presentation/
    ├── providers/       # Riverpod notifiers and providers
    ├── views/           # Screen-level widgets (one file per screen)
    └── widgets/         # Feature-specific reusable widgets
```

### 15.2 View Naming Convention

All screen files end in `_view.dart`. The widget class name ends in `View`:

```
units_list_view.dart  →  class UnitsListView
unit_detail_view.dart →  class UnitDetailView
unit_form_sheet.dart  →  class UnitFormSheet  (exception: bottom sheets)
```

### 15.3 Existing Features (as of 2026-04-16)

```
achievements / activities / annual_folders / auth / camporees /
certifications / classes / club / coordinator / dashboard /
enrollment / evidence_folder / finances / home / honors /
insurance / inventory / investiture / members / monthly_reports /
notifications / post_registration / profile / resources /
role_assignments / transfers / units / validation
```

### 15.4 Core Utilities

| File | Purpose |
|------|---------|
| `lib/core/utils/icon_helper.dart` | `HugeIconData` typedef + `buildIcon()` |
| `lib/core/utils/validators.dart` | Common form validators |
| `lib/core/utils/responsive.dart` | Screen size helpers |
| `lib/core/utils/role_utils.dart` | Role string helpers |
| `lib/core/utils/date_formatter.dart` | Date formatting |
| `lib/core/utils/extensions.dart` | Dart extension methods |
| `lib/core/utils/app_logger.dart` | Structured logging |
| `lib/core/config/router.dart` | go_router configuration |
| `lib/core/config/route_names.dart` | Route name constants |

---

## 16. Accessibility and i18n

- `flutter_localizations` is included for locale support
- `intl: ^0.20.1` for date/number formatting
- Text is in Spanish (es-MX) by default
- Button text: infinitives ("Guardar", "Cancelar", "Eliminar")
- Loading text: gerunds ("Guardando...", "Cargando...")
- `MediaQuery.disableAnimations` is respected in all custom animations

---

## 17. Known Inconsistencies (explicit — prefer the canonical pattern listed)

1. **Empty state widget**: No shared `SacEmptyState` exists. Each feature implements
   its own. Pattern A (section 11.2) is the de-facto standard. A future agent should
   create a `core/widgets/sac_empty_state.dart` and migrate features to it.

2. **`SacLoadingSmall` vs `SacLoading`**: Both render wave dots at 30px. They are
   functionally identical. Use `SacLoading` for all cases unless size needs to differ.

3. **BottomNavigationBar vs NavigationBar**: The dashboard uses one or the other
   depending on the build — both are themed in `AppTheme`. Check the actual
   `dashboard_view.dart` for which one is active when building new tabs.

4. **Dialogs**: `SacDialog` is the standard. Some older screens use `showDialog`
   with a raw `AlertDialog` (Material). Prefer `SacDialog` for all new code.

5. **Icon usage**: The majority of screens use HugeIcons. A few older widgets use
   `Icons.*` (Material). New widgets must use HugeIcons exclusively.
