# SACDIA App - Design System & Style Guide (Flutter)

> This document describes what IS IMPLEMENTED in the codebase as of the audit date.
> Follow these patterns when adding new screens or widgets.
> Do NOT invent new patterns — if something is inconsistent across screens, this doc
> explicitly calls it out and recommends the canonical path.

> **DS v2 — 2026-11-03**
> Design identity: "Scout Vibrante" — Duolingo gamification + Apple Health minimalism.
> White backgrounds, vibrant accents, progress as protagonist.

### Changelog 2026-11-04 — color/state foundation

- **Status containers**: `SacColors` gains `success/warning/error/infoContainer` and their `on*Container`, per mode (§2.7). `onSuccess`/`onWarning`/`onInfo` now are ink (`#131316`) because white and `accentDark` failed AA on the solid fills.
- **`SacBadge`**: variants resolve through the container tokens (dark-aware, AA), new `info` variant, dark `primary` tints over the surface (§6.2).
- **`SacSnackBar`**: new `isSuccess` (neutral bar + green check), `isError` forces white text (§6.9b). Green `backgroundColor:` overrides are banned.
- **Ratchet guard**: `semantic_states_ratchet_test.dart` freezes the remaining light-only pastels and `e.toString()` leaks (§18).
- **Formatting**: dates follow the app language (`Intl.defaultLocale` synced in `main.dart`, no hardcoded `'es'`); all money goes through `SacMoney` (es_MX, no `MXN` suffix, tabular figures). Both are hard bans in the ratchet (§16.1, §18).

### v2 changelog (2026-11-03)

The app's screens had settled on a style that differed from what v1 prescribed. After
review, the screens' style won: this doc now follows the code, not the other way round.

- **Type scale**: tokens live in `SacFontSize`; `titleLarge` 17, `titleMedium` 15, `bodyLarge` 15, `bodyMedium` 13, `labelSmall` 11 (all were 1px+ larger/smaller). Matches Apple's scale. See §3.
- **Radius**: cards are 14 (was 16); new `radiusHairline` (2) and `radius2XS` (4). See §4.1.
- **Color**: the primary color is the user-selected accent (`SacAccent`, default "Azul SACDIA"), no longer fixed coral. Light neutrals use the single ink scale; slate is gone. See §2.
- **Feature palettes**: every hardcoded color moved to a token: `context.sac`, `AppColors` status/brand tokens, or a feature `*_tokens.dart`. New shared tokens: skeleton colors and recognition gold. See §2.7.
- **Enforcement**: a guard test blocks literal font sizes, radii and `Color(0x…)` literals outside token files. See §18.

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

### 2.1 Brand Colors and the Accent

**The primary color is the user's accent**, not a fixed constant. `SacAccent`
(`lib/core/theme/sac_accent.dart`) is a `ThemeExtension` registered in the theme;
`ColorScheme.primary` equals `accent.color`, so `Theme.of(context).colorScheme.primary`
and `SacAccent.of(context).color` return the same value. Buttons, links, focus
rings, switches, progress and navigation selection all follow it. The default is
`SacAccent.logoBlue` ("Azul SACDIA").

```dart
final accent = SacAccent.of(context);
accent.color     // main accent: buttons, links, focus
accent.onColor   // foreground on top of accent.color
accent.light     // tint for badges, chips, selection (primaryContainer)
accent.dark      // pressed / secondary-button text (onPrimaryContainer)
accent.surface   // very subtle selection tint
```

Accent catalog (`SacAccent.catalog`; the user picks one in Settings):

| Accent | Color | Source |
|--------|-------|--------|
| `SacAccent.logoBlue` (default) | `#0B84F0` | `AppColors.loginBrandBlue` |
| `SacAccent.coral` | `#F06151` | `AppColors.primary` |
| `SacAccent.aventureros` | `#2EA0DA` | `AppColors.info` |
| `SacAccent.conquistadores` | `#F06151` | `AppColors.primary` |
| `SacAccent.guiasMayores` | `#4FBF9F` | `AppColors.secondary` |
| 15 class accents (`class.*`) | per-class color | `AppColors.color*` (see §2.8) |

Rules:
- Paint primary actions with the accent (`SacAccent.of(context)` or `colorScheme.primary`), never with the `AppColors.primary` constant. `AppColors.primary` is the fixed coral (also Conquistadores' red) and is only the right choice when you literally mean that coral.
- `AppColors.primaryLight/primaryDark/primarySurface` below are the coral family's tints. They back `SacAccent.coral`/`conquistadores`; other accents derive their own `light`/`dark`/`surface`.
- Dark mode and high-contrast adjust the accent through `forBrightness` / `forHighContrast`; do not re-implement that.

| Token | Value | Role |
|-------|-------|------|
| `AppColors.primary` | `#F06151` | Fixed coral: coral accent, Conquistadores red, `coral500` |
| `AppColors.primaryLight` | `#FDE8E6` | Coral accent's tint (badges, chips, secondary button bg) |
| `AppColors.primaryDark` | `#D94A3B` | Coral accent's pressed state / secondary button text |
| `AppColors.primarySurface` | `#FFF1EF` | Coral accent's very subtle selection tint |
| `AppColors.secondary` | `#4FBF9F` | Success, completed, progress, nature/scout |
| `AppColors.secondaryLight` | `#E0F5EF` | Success badge background |
| `AppColors.secondaryDark` | `#2D8A70` | Success text |
| `AppColors.accent` | `#FBBD5E` | Stars, achievements, rewards, in-progress |
| `AppColors.accentLight` | `#FFF4E0` | In-progress badge background |
| `AppColors.accentDark` | `#B8862B` | Warning text |
| `AppColors.error` | `#DC2626` | Errors, destructive actions (differentiated from primary) |
| `AppColors.errorLight` | `#FEE2E2` | Error badge background |
| `AppColors.errorDark` | `#991B1B` | Error text |

### 2.1b Logo brand — `logo-sacdia.png`

The logo blue is no longer login-only: it is the default accent (`SacAccent.logoBlue`)
and so the default primary color across the app. The `AppColors.loginBrand*` tokens
remain the logo-locked source values.

| Token | Value | Role |
|-------|-------|------|
| `AppColors.loginBrandBlue` | `#0B84F0` | Value of `SacAccent.logoBlue.color`; splash/login capsule CTA, splash loader |
| `AppColors.loginBrandBlueDark` | `#0666C9` | `SacAccent.logoBlue.dark`; text links on white (contrast) |
| `AppColors.loginBrandGold` | `#F0B000` | Hairline under the wordmark |

These tokens are the same in light and dark (logo-locked). Using `AppColors.loginBrand*` in auth paint (splash/login) is the exception to §2.7; elsewhere use the accent.

### 2.2 Surface Tokens — Light Mode

| Token | Value | Role |
|-------|-------|------|
| `AppColors.lightBackground` | `#FFFFFF` | Main scaffold background |
| `AppColors.lightSurface` | `#FFFFFF` | Cards, modals, bottom sheets |
| `AppColors.lightSurfaceVariant` | `#F7F8FA` | Alternate sections, secondary backgrounds |
| `AppColors.lightBorder` | `#E3E5EA` | Card borders, dividers |
| `AppColors.lightBorderLight` | `#F2F4F7` | Very subtle separators |
| `AppColors.lightDivider` | `#E3E5EA` | Divider alias |

There is ONE neutral scale: the ink scale (`ink50`…`ink900`, see §2.7). Light-mode
surface/border/text tokens are aliases of its steps; the old slate palette is gone.

### 2.3 Text Tokens — Light Mode

| Token | Value | Role |
|-------|-------|------|
| `AppColors.lightText` | `#131316` | Titles, primary text (= ink900) |
| `AppColors.lightTextSecondary` | `#6B7280` | Subtitles, descriptions (= ink500) |
| `AppColors.lightTextTertiary` | `#9AA0AB` | Placeholders, hints, metadata (= ink400) |

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

Raw aliases in `AppColors` (same value in both modes; paint code reads them through `context.sac` — see §2.7):

```dart
AppColors.success  = AppColors.secondary  (#4FBF9F)
AppColors.warning  = AppColors.accent     (#FBBD5E)
AppColors.info     = AppColors.sacBlue    (#2EA0DA)
AppColors.error    = Color(0xFFDC2626)
```

Use `context.sac.*` getters instead — see §2.7. What is actually light-only are the pastels `AppColors.*Light` / `light*` (and `primarySurface`): they glare on the OLED dark theme, so use the `xContainer` tokens instead.

### 2.7 Dark-Mode Aware Color Resolution — MANDATED PATTERN

**`context.sac` (the `SacColors` extension on `BuildContext`) is the MANDATED pattern for all color access in widget paint code.**

NEVER use `AppColors.*` directly in widget paint code. `AppColors` constants are not theme-aware (the `*Light` / `light*` pastels are light-only and glare in dark mode). The `SacColors` extension resolves the correct variant automatically based on `Theme.of(context).brightness`.

```dart
// File: lib/core/theme/sac_colors.dart
final c = context.sac;

// Surfaces
c.background      // white / #000000 (true black OLED)
c.surface         // white / #1A1A1A
c.surfaceVariant  // #F7F8FA / #252525
c.border          // #E3E5EA / #303030
c.divider         // alias for border
c.borderLight     // #F2F4F7 / #252525
c.shadow          // rgba(0,0,0,0.08) / rgba(255,255,255,0.04)

// Text
c.text            // #131316 / #F2F2F2
c.textSecondary   // #6B7280 / #8C8C8C
c.textTertiary    // #9AA0AB / #5C5C5C

// Neutral "ink" scale (theme-resolved replacement for the deprecated
// light-only AppColors.inkNNN / paper / canvas). Semantics = ink strength:
// ink900 primary text, ink500 secondary, ink150 border, ink50 row bg.
// In dark the scale inverts; endpoints align with AppColors.dark*.
c.ink900          // #131316 / #F2F2F2
c.ink800          // #20232A / #E4E4E4
c.ink700          // #2C313B / #CFCFCF
c.ink600          // #4B5260 / #B8B8B8
c.ink500          // #6B7280 / #9A9A9A
c.ink400          // #9AA0AB / #7A7A7A
c.ink300          // #C7CBD2 / #4A4A4A
c.ink200          // #E3E5EA / #383838
c.ink150          // #ECEEF2 / #303030
c.ink100          // #F2F4F7 / #2A2A2A
c.ink50           // #F7F8FA / #252525
c.paper           // #FFFFFF / #1A1A1A  (card / app bar surface)
c.canvas          // #FAFAFB / #000000  (screen background)

// On-surface
c.onPrimary       // Colors.white (both modes)
c.barrierColor    // rgba(0,0,0,0.5) / rgba(0,0,0,0.7)

// Semantic state. Solid fills: same value in both modes.
c.success         // #4FBF9F
c.onSuccess       // #131316 (ink on solid green, 8.2:1)
c.warning         // #FBBD5E
c.onWarning       // #131316 (ink on solid yellow, 11.1:1)
c.info            // #2EA0DA
c.onInfo          // #131316 (ink on solid blue, 6.3:1)
c.error           // #DC2626
c.onError         // Colors.white (4.83:1)

// Status containers (tinted backgrounds), light / dark
c.successContainer    // #E0F5EF / #253B35
c.onSuccessContainer  // #1E6B55 / #6FD3B6
c.warningContainer    // #FFF4E0 / #473B28
c.onWarningContainer  // #8A5A00 / #FBBD5E
c.errorContainer      // #FEE2E2 / #491D1D
c.onErrorContainer    // #991B1B / #FCA5A5
c.infoContainer       // #EFF6FF / #1E3540
c.onInfoContainer     // #0B6699 / #7CC4EE
```

**Status color rule.** Status tint backgrounds use `xContainer`; status text and icons use `onXContainer`. That `onXContainer` is also the color for status-colored text placed directly on `surface`/`background` (at least 5.4:1 on white and on `#1A1A1A`/`#000`). `onX` (no `Container`) is only for text on a solid `x` fill. A border or a decorative fill may use the solid `x` token.

**Known tech-debt — light-only pastels pending migration:**
About 165 uses of `AppColors.*Light` / `light*` remain in feature presentation (frozen by the ratchet test, §18). Replace them with the container tokens when you touch the file. Future agents: do NOT add more `AppColors.*` calls for colors that must adapt to dark mode — use `context.sac.*`. (Hardcoded `Color(0xFF…)` literals were removed from paint code in v2.)

**2026-09-04 — neutral-scale audit:** `AppColors.inkNNN`, `AppColors.paper` and `AppColors.canvas` are now `@Deprecated`; every screen that used them (Clases module, Investiduras history, Materiales checkout, Honor completion) was migrated to `context.sac.inkNNN` / `paper` / `canvas`. Feature-scoped palettes follow the same rule: `MedicoTokens.of(context)` (`MedicoPalette`) for Información Médica and its edit sub-screens.

**v2 — feature token files.** `AppColors.coral500` now equals `AppColors.primary` (`#F06151`), and `MedicoTokens.coral500` points to it. A feature's own palette (categorical data, tiers, flags, decorative art) lives in a `*_tokens.dart` file next to the feature, with named `static const` colors:

| File | Holds |
|------|-------|
| `profile/.../medico/medico_tokens.dart` | Información Médica palette |
| `classes/presentation/roadmap/theme/roadmap_tokens.dart` | Roadmap track and status colors |
| `virtual_card/.../credencial/credencial_tokens.dart`, `virtual_card/presentation/theme/virtual_card_tokens.dart` | Credential artwork, QR tile, overlays |
| `achievements/presentation/theme/achievement_tokens.dart` | Achievement tiers (bronze → diamond) and their chips |
| `rankings/presentation/theme/ranking_tokens.dart` | Ranking and award tiers |
| `finances/presentation/theme/finance_tokens.dart` | Category accents |
| `activities/presentation/theme/activities_tokens.dart` | Attendee avatar palettes |
| `dashboard/presentation/theme/dashboard_tokens.dart` | Birthday medallion and gold shimmer |
| `settings/presentation/theme/settings_tokens.dart` | Language flag stripes |
| `auth/presentation/theme/auth_tokens.dart` | Welcome carousel washes |
| `core/animations/celebration_tokens.dart` | Confetti colors shared by every celebration |
| `core/notifications/push_banner_tokens.dart` | Tier accents on the always-dark push banner |

Shared tokens added in v2:

- `context.sac.skeleton`, `skeletonHighlight` and `skeletonSurface`: loading-skeleton blocks, their lighter fill, and the card behind them (darker than the blocks in dark mode, so they keep contrast).
- `AppColors.gold`, `goldDark` and `goldLight`: recognition gold (member of the month, first places).

There are no `Color(0x…)` literals outside `lib/core/theme/` and `*_tokens.dart` files; the guard test (§18) keeps it that way. Shadows and scrims use `Colors.black` / `Colors.white` `.withValues(alpha: …)`. Brand-locked surfaces are exempt and documented in place: Credencial digital (gradient card, white QR zone) and the Clases roadmap (sky-gradient background).

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

For a plain info badge use `SacBadge.info` (`infoContainer` / `onInfoContainer`, §2.7). The `statusInfo*` pair below is only for the validation "sent" badge.

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

### 3.2 Type Scale (Material 3 TextTheme, v2)

Sizes come from `SacFontSize` (`lib/core/theme/sac_font_size.dart`), which
`app_theme.dart` re-exports, so importing `app_theme.dart` is enough. The scale
matches Apple's type scale because the app renders in SF Pro.

| Style | `SacFontSize` | Size | Weight | Color (light) | Role |
|-------|---------------|------|--------|---------------|------|
| `displayLarge` | `displayLarge` | 32 | w700 | lightText | Hero headers, splash |
| `displayMedium` | `displayMedium` | 28 | w700 | lightText | Screen main title |
| `displaySmall` | `displaySmall` | 24 | w700 | lightText | Section title |
| `headlineLarge` | `headlineLarge` | 22 | w600 | lightText | Section headers |
| `headlineMedium` | `headlineMedium` | 20 | w600 | lightText | Card headers, app bar titles |
| `headlineSmall` | `headlineSmall` | 18 | w600 | lightText | Sub-section headers |
| `titleLarge` | `titleLarge` | 17 (was 18) | w500 | lightText | Card titles |
| `titleMedium` | `titleMedium` | 15 (was 16) | w500 | lightText | List-row titles |
| `titleSmall` | `titleSmall` | 14 | w500 | lightText | Compact titles |
| `bodyLarge` | `titleMedium` | 15 (was 16) | w400 | lightText | Long-form body, height 1.5 |
| `bodyMedium` | `bodyMedium` | 13 (was 14) | w400 | lightText | Standard body, height 1.5 |
| `bodySmall` | `bodySmall` | 12 | w400 | lightTextSecondary | Metadata, height 1.5 |
| `labelLarge` | `titleSmall` | 14 | w600 | lightText | Buttons, badges |
| `labelMedium` | `bodySmall` | 12 | w500 | lightTextSecondary | Chips, secondary labels |
| `labelSmall` | `labelSmall` | 11 (was 10) | w500 | lightTextTertiary | Eyebrows, section labels, micro labels |

Display styles also use `letterSpacing: -0.5`.

Steps in `SacFontSize` that are not `textTheme` roles:

| Step | Size | Purpose |
|------|------|---------|
| `nano` | 7 | Digits inside very small badges and avatar overlays |
| `micro` | 9 | Compact badges and chart axis labels |
| `caption` | 10 | Smallest regular text: footnotes and dense captions |
| `metricSmall` | 36 | Large figures in summary cards (balances, scores, stats) |
| `metric` | 44 | Hero figures, such as a class progress percentage |

### 3.3 Typography Rules

- AppBar titles: `fontSize: SacFontSize.headlineMedium` (20), `fontWeight: w700`, text color (set globally by `AppBarTheme`; do not override)
- Prefer `Theme.of(context).textTheme.<role>` over a hand-built `TextStyle`
- When a custom `TextStyle` is needed (own weight, tracking or color), use `fontSize: SacFontSize.<step>`
- Literal `fontSize:` numbers are forbidden outside `lib/core/theme/` (guard test, §18). `fontSize: 0` is the only exception
- Decimal sizes (11.5, 12.5, 13.5) are not allowed: pick the nearest step
- Use `.copyWith()` only for overrides (color, weight changes)

---

## 4. Spacing and Radius

### 4.1 Radius Scale

```dart
// lib/core/theme/app_theme.dart
AppTheme.radiusHairline = 2.0    // progress bars, hairlines
AppTheme.radius2XS      = 4.0    // tiny elements
AppTheme.radiusXS       = 8.0    // micro elements
AppTheme.radiusSM       = 12.0   // inputs, buttons, list tiles
AppTheme.radiusMD       = 14.0   // cards (main card radius; SacCard uses it)
AppTheme.radiusLG       = 20.0   // bottom sheets (vertical top only), chips
AppTheme.radiusXL       = 24.0   // large containers
AppTheme.radiusFull     = 100.0  // pills, FABs, avatars
```

`radiusHairline` and `radius2XS` are new in v2; `radiusMD` was 16.

Literal radii are forbidden outside `lib/core/theme/` (guard test, §18). Use:

```dart
BorderRadius.circular(AppTheme.radiusMD)
const Radius.circular(AppTheme.radiusLG)
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
(e.g. `SacButton`, `DashboardCard`) keep `dynamic` and dispatch
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

The primary button widget. Custom pressable: `GestureDetector` + `DecoratedBox`.
Press is `AnimatedScale(0.97)` over 140ms with `SacMotion.easeOut` and
`HapticFeedback.lightImpact()`. No Material splash / `ElevatedButton`.
Keyboard activation uses `FocusableActionDetector` (`ActivateIntent`).

**Variants (`SacButtonVariant`):**

| Variant | Background | Foreground | Border |
|---------|-----------|-----------|--------|
| `primary` | `accent.color` | `accent.onColor` | none |
| `secondary` | `accent.light` | `accent.dark` | none |
| `outline` | transparent | `accent.color` | `accent.color 1.5px` |
| `ghost` | transparent | `accent.color` | none |
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

**Disabled state:** the button keeps its variant colors (background, text, border) and is dimmed to `AppTheme.disabledOpacity` (0.4), so a disabled primary still reads as the primary action, just "not yet". It never scales on press. Loading is not disabled: it keeps full opacity and shows the spinner.

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
| `primary` | light: `SacAccent.light`; dark: accent at 20% over `c.surface` | light: `SacAccent.dark`; dark: `forHighContrast(Brightness.dark)` |
| `secondary` (success shortcut) | `c.successContainer` | `c.onSuccessContainer` |
| `accent` (warning shortcut) | `c.warningContainer` | `c.onWarningContainer` |
| `error` | `c.errorContainer` | `c.onErrorContainer` |
| `info` | `c.infoContainer` | `c.onInfoContainer` |
| `neutral` | `c.surfaceVariant` | `c.textSecondary` |

Every status variant is dark-aware and AA (the container pairs are verified). Do not pass
`AppColors.*Light` as `backgroundColor`; pick the variant.

**Named constructors:**
- `SacBadge.success(label:)` — maps to `secondary` variant
- `SacBadge.warning(label:)` — maps to `accent` variant
- `SacBadge.error(label:)` — maps to `error` variant
- `SacBadge.info(label:)` — maps to `info` variant

Icon: `HugeIconData?`, drawn via `buildIcon()` at 14px.
Border radius: 20px (pill).
Text: `fontSize: SacFontSize.bodySmall` (12), `fontWeight: w500`.

```dart
SacBadge(label: 'Activo', variant: SacBadgeVariant.secondary)
SacBadge.error(label: 'Error', icon: HugeIcons.strokeRoundedAlertCircle)
```

### 6.3 SacCard

**File:** `lib/core/widgets/sac_card.dart`

The standard card container. White/dark surface, `lightBorder`, subtle shadow (`blurRadius: 8, offset: (0,2)`), `radiusMD` (14px).

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

iOS-inspired dialog. Rounded 20px, surface bg, accent-colored icon and actions,
iOS-style horizontal action buttons separated by 0.5px dividers.
Scale + fade entrance animation using `SacMotion.modal` (240ms) and
`SacMotion.easeOut`, from `SacMotion.enterScale` (0.96) to 1.0. With
Reduced Motion enabled it keeps only the `SacMotion.reducedFade` (160ms) fade;
it does not scale.

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

Actions use `SacButton` (scout press, no Material ripple).

**Optional `body` for forms:**

Use `body` when the dialog needs fields (`SacTextField`, `Form`). Title and
`content` stay as copy; `body` sits below them. For custom actions or
validation before pop, use `SacDialog.present` instead of `show`.

```dart
final confirmed = await SacDialog.present<bool>(
  context,
  builder: (ctx) => SacDialog(
    title: 'Rechazar',
    content: 'Escribe el motivo.',
    body: Form(
      key: formKey,
      child: SacTextField(controller: reasonCtrl, validator: ...),
    ),
    actions: [
      SacDialogAction(
        label: 'Cancelar',
        style: SacDialogActionStyle.cancel,
        onPressed: () => Navigator.pop(ctx, false),
      ),
      SacDialogAction(
        label: 'Rechazar',
        style: SacDialogActionStyle.destructive,
        onPressed: () {
          if (formKey.currentState!.validate()) {
            Navigator.pop(ctx, true);
          }
        },
      ),
    ],
  ),
);
```

**Action styles (`SacDialogActionStyle`):**

| Style | Color | Weight |
|-------|-------|--------|
| `confirm` | `AppColors.coral700` | w600 |
| `success` | `AppColors.secondary` | w600 |
| `destructive` | `AppColors.error` | w600 |
| `cancel` | `context.sac.textSecondary` | w600 |

### 6.6 SacLoading / SacLoadingSmall

**File:** `lib/core/widgets/sac_loading.dart`

Primary loading indicator: animated wave dots (`loading_animation_widget`).
With Reduced Motion, both loading widgets render the same-size static
three-dot mark instead of the wave animation.

```dart
// Full screen loading
Center(child: SacLoading())

// Custom color
SacLoading(color: AppColors.secondary)

// Compact (both use a 30px loading field)
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
`SacMotion.easeOut` over the configurable 700ms default. An optional shimmer
can sweep once after the fill. With Reduced Motion, the bar immediately shows
its final value and never runs the shimmer.

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
- `showShimmer: false` (default) — enable only for a one-time loading cue

### 6.8 SacProgressRing

**File:** `lib/core/widgets/sac_progress_ring.dart`

Animated ring progress indicator. Apple Health / Fitness style.
Sweep gradient (`primary` → secondary). Rounded stroke caps. It fills with
`SacMotion.easeOut` over the configurable 900ms default; with Reduced Motion,
it immediately renders its final value without the delayed entrance.

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
| `SacEmptyState` | `sac_empty_state.dart` | Canonical empty / no-data placeholder (icon 56, title, optional body + CTA) |
| `SacErrorState` | `sac_error_state.dart` | Full-area error placeholder: icon, title, optional message, optional retry. `SacErrorState.forbidden()` is the 403 variant (lock icon, no retry). Accepts `padding` to sit below a frosted `SacTopBar` |
| `SacStatTile` | `sac_stat_tile.dart` | KPI tile on `SacCard`: tinted icon circle, `AnimatedCounter` value (`decimals` for fractions), label, `SacStatTone` (neutral/warning/error/success/accent), optional `onTap`; `SacStatTile.skeleton()` for loading |

### 6.9b SacSnackBar

**File:** `lib/core/widgets/sac_snack_bar.dart`

Canonical toast: `SacSnackBar.show(context, message, ...)` (or `showMessenger` after an async gap).

| Flag | Result |
|------|--------|
| default | Neutral theme bar (dark ink in light theme, `#F2F2F2` in dark) |
| `isSuccess: true` | Same neutral bar plus a leading green check (`#4FBF9F` on the light theme, `#1E6B55` on the dark one; 8.2:1 / 5.7:1). A caller-provided `leading` wins |
| `isError: true` | `AppColors.error` bar, content text and close icon forced white (4.83:1; black on red was 4.35:1 in dark) |

`isError` and `isSuccess` are mutually exclusive (asserted). Do not color a success toast with
`backgroundColor: AppColors.secondary` (white on it is 2.26:1); the ratchet test (§18) forbids it.
`backgroundColor` stays for rare custom tones.

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

The following widget is deprecated and must NOT be used in new code:

| Deprecated | Canonical replacement | Prop mapping |
|------------|----------------------|-------------|
| `CustomTextField` (`custom_text_field.dart`) | `SacTextField` (`sac_widgets.dart`) | `controller` → `controller`, `labelText` → `label`, `hintText` → `hint`, `validator` → `validator`, `prefixIcon` → `prefixIcon` |

`CustomButton` was removed. Use `SacButton`. `CustomTextField` is annotated with `@Deprecated(...)` at the class level. The Dart analyzer will emit warnings in any file that references it. Do not suppress those warnings — they are intentional signals to migrate.

**Migration — existing consumers:** There are existing callers of `CustomTextField` throughout the codebase. Do NOT mass-migrate them in a single commit — migrate per feature/screen as part of normal development. The `@Deprecated` annotation is the tracking mechanism.

---

## 7. Theme Configuration

### 7.1 ThemeData Setup

**Files:**
- `lib/core/theme/app_theme.dart` — `AppTheme.lightTheme` and `AppTheme.darkTheme`
- `lib/core/theme/app_colors.dart` — all color constants
- `lib/core/theme/sac_colors.dart` — `SacColors` extension on `BuildContext`
- `lib/core/theme/theme_provider.dart` — Riverpod `ThemeNotifier`

**Material 3 is enabled** (`useMaterial3: true`). `AppTheme.buildLight(SacAccent)` builds the light theme for the chosen accent (`AppTheme.lightTheme` = `SacAccent.logoBlue`); "primary" in the list below means the accent.

**Component themes configured globally** (do not override in individual screens):
- `AppBarTheme`: white/black bg, elevation 0, `scrolledUnderElevation: 0.5`, `centerTitle: false`, title `SacFontSize.headlineMedium` (20) w700 in text color
- `CardTheme`: surface bg, elevation 0, radiusMD (14) with border
- `ElevatedButtonTheme`: accent bg, `accent.onColor` fg, 0 elevation, radiusSM, h:48
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
| Shared-axis (horizontal slide) | `sharedAxisPage<T>()` | 240ms enter / 200ms reverse | Standard forward/back navigation |
| Fade-through | `fadeThroughPage<T>()` | 160ms | Tab switches, peer-level navigation |
| Slide-up | `slideUpPage<T>()` | 240ms enter / 200ms reverse | Bottom sheet as page, modal flows |

All transitions respect `MediaQuery.disableAnimations`. Under Reduced Motion,
shared-axis and slide-up remove translation and retain only the fade.

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

Use `SacEmptyState` (`lib/core/widgets/sac_empty_state.dart`) for new screens. Older
feature screens implement their own inline empty states, typically:

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
        style: TextStyle(fontSize: SacFontSize.titleMedium, color: c.textSecondary),
      ),
    ],
  ),
)
```

**Note**: pattern is inconsistent across legacy features. For new screens use
`SacEmptyState`, not a hand-rolled copy of Pattern A.

### 11.3 Error State

Use `SacErrorState` for full-area failures (`SacErrorState.forbidden()` for 403) and a
compact inline card with a retry button for a failing section inside a larger screen.
Never show `error.toString()` to users; use localized copy. Legacy inline pattern:

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
  color: SacAccent.of(context).color,
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
- White background (`context.sac.background`) — same canvas as the rest of the app
- Brand mark: `SacBrandMark` from `assets/img/logo-sacdia.png` (squircle + soft shadow)
- Gold hairline (`AppColors.loginBrandGold`) under the wordmark
- `SacTextField` for email/password (do not restyle the field itself)
- Rate limiting: 3 failed attempts → 30s cooldown with countdown display
- Capsule CTA using `AppColors.loginBrandBlue` (logo blue, which is also the default accent `SacAccent.logoBlue`)
- Entrance: `StaggeredColumn` with `SacMotion` tokens; splash uses fade+scale from `SacMotion.enterScale` (0.96)

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

`SacMotion` (`lib/core/animations/motion_tokens.dart`) is the canonical motion
policy. Use its duration, curve, scale, and `reduceMotionOf(context)` tokens
instead of new literal values. Core motion re-evaluates
`MediaQuery.disableAnimations` when dependencies change.

### 14.1 Card Entrance (Stagger)

```dart
// Stagger a list of cards manually
SacCard(
  animate: true,
  animationDelay: Duration(milliseconds: index * 80),
  child: ...,
)
```

With Reduced Motion, card entrances resolve to their final layout immediately:
no scale animation or delay.

### 14.2 Staggered List Animation

**File:** `lib/core/animations/staggered_list_animation.dart`

Use `StaggeredListItem` or `StaggeredColumn` for lists that should animate
items in sequence. They read `MediaQuery.disableAnimations`; with Reduced
Motion, items render immediately without stagger or slide.

### 14.3 Page Transitions

Use `sharedAxisPage`, `fadeThroughPage`, or `slideUpPage` in the router
(section 8.3). Never define custom `PageRoute` classes outside `page_transitions.dart`.

### 14.4 Scale Press on Buttons

`SacButton` applies `AnimatedScale(scale: 0.97)` on `TapDown` (140ms,
`SacMotion.easeOut`) with `HapticFeedback.lightImpact()`. Reduced motion
keeps scale at 1. Do NOT add redundant `GestureDetector` wrappers around
`SacButton` — the animation is already built in.

### 14.5 Celebration Overlay

**File:** `lib/core/animations/celebration_overlay.dart`

Used for achievement unlocks and gamification moments. Renders over the screen.

### 14.6 Animated Counter

**File:** `lib/core/animations/animated_counter.dart`

Animates a numeric value from old to new over a duration. Use for KPI cards and
score displays. It reacts to `MediaQuery.disableAnimations`; with Reduced
Motion, it cancels delayed counting and displays the final value immediately.

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
- Motion policy: `SacMotion.reduceMotionOf(context)` reads
  `MediaQuery.disableAnimations` for shared primitives and routes.
- Scope: this applies to the shared primitives documented here, the registered
  page transitions, list and counter helpers, and achievement badge loops. It
  does not redefine component-specific interaction feedback such as
  `SacButton`'s press scale.
- Within that scope, Reduced Motion omits slide, scale, pulse, shimmer, and
  stagger effects; progress, rings, and counters settle on their final values,
  and loading dots are static. A gentle fade may remain where it preserves
  navigation or dialog context.
- Decorative achievement shimmer and pulse loops stop and reset while Reduced
  Motion is enabled.

### 16.1 Formatting: money and dates

**Money** (`lib/core/utils/money_format.dart`, `SacMoney`):
- Every amount uses `SacMoney.format(pesos)` / `fromCentavos(centavos)` -> "$1,234.50". Signed rows (`signed: true`) show "+$" or "−$" (U+2212).
- `SacMoney.compact` ("$950", "$1.2k", "$12k", "$1.5M") only for tight spaces (chart axes, stat chips).
- Fixed to es_MX on purpose: amounts are always MXN, so money does NOT change with the app language. Never show an "MXN" suffix.
- Amount `TextStyle`s use `fontFeatures: SacMoney.tabularFigures` so digits align in columns.
- No `NumberFormat.currency` outside `SacMoney` (ratchet). Editable form values stay plain numbers.

**Dates** follow the app language:
- `main.dart` keeps `Intl.defaultLocale` equal to the easy_localization locale (pt-BR -> `pt_BR`) and loads date symbols at startup. Use `DateFormat(pattern)` with NO locale argument, or `SacDateFormatter`. Never pin `'es'` (ratchet).
- `DateFormat` captures the locale when it is built: do not keep one in a `static final`; build it per use or in `didChangeDependencies`.
- Avoid Spanish literals in patterns (`'de'`); use skeletons such as `DateFormat.yMMMMd()`.
- Calendar dates (`start_date`, `YYYY-MM-DD`): `parseCalendarDate` + `formatCalendar` / `range` (no UTC -> local). Timestamps (`created_at`): `format` / `toLocal()`.
- Ranges: `SacDateFormatter.range(start, end)` -> "3 – 5 abr 2026", "28 mar – 2 abr 2026".
- Tests start in `es` (`test/flutter_test_config.dart`); set `Intl.defaultLocale` explicitly to test another language.

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

---

## 18. Design token guard

`test/core/theme/semantic_states_ratchet_test.dart` is a separate ratchet over
`lib/features/**/presentation/**`. It keeps a checked-in baseline (file → count) for:

- light-only pastels `AppColors.(*Light|light*|primarySurface)` (use `xContainer` tokens, §2.7)
- `e.toString()` / `err.toString()` / `error.toString()` (use `SacErrorState` + `userErrorMessage`)
- green `backgroundColor:` on `SacSnackBar` calls (empty baseline = hard ban; use `isSuccess`)
- `NumberFormat.currency/simpleCurrency/compactCurrency` anywhere in `lib/**` (hard ban; use `SacMoney`, §16.1)
- a `DateFormat` with a quoted `'es'` locale anywhere in `lib/**` (hard ban; dates follow the app language, §16.1)

A file can never exceed its baseline, and new files start at zero. When a count drops, the
test fails until the baseline is lowered, so the debt only shrinks.

### 18.1 Token literals

`test/core/theme/design_tokens_guard_test.dart` scans `lib/` (except `lib/core/theme/`)
and fails on:

- literal `fontSize:` numbers (use `SacFontSize.<step>`, §3). `fontSize: 0` is allowed
- literal `BorderRadius.circular(n)` / `Radius.circular(n)` (use `AppTheme.radiusX`, §4.1)
- any `Color(0x…)` literal (use `context.sac`, `AppColors`, `SacAccent`, or the feature's `*_tokens.dart`, §2.7)

Comment lines (`//`, `///`) are ignored.

Exempt files and folders:

- `*_tokens.dart` (feature palettes, §2.7)
- `*sprites*.dart`
- `lib/features/auth/presentation/widgets/welcome_carousel_visuals.dart` and `welcome_carousel_world.dart` (illustrations)
- `lib/features/virtual_card/presentation/widgets/credencial/` (fixed-layout credential artwork)

A single line can opt out with a trailing comment:

```dart
fontSize: 72, // ds-allow: placeholder initial sized to the image area
```

Use it only when no token fits, and always give the reason. When the test fails, fix
the code (use the token); a new palette goes into the feature's `*_tokens.dart`.
