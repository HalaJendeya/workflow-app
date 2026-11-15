# UI refinement — compact layouts, language and theme (2026-11-15)

## 1. Content-first layouts

| Pattern | Before | After |
|---|---|---|
| Statistics | One full-width card per number (`MetricCard`, `IconMetricCard`): title, 20 px value, delta badge, ~160 px each | `MetricGroup`: related figures in one card, 2–3 per row (3 only for short values and when 96 px × text scale fits), odd last cell spans the row, hairline dividers; no delta badge without data |
| Dashboard figure lists | Label over value, one per line | Runs of short figures (≤ 22 chars) two per row (`LabelValueGrid`); sentences stay full width |
| Allocation ring | 160 px ring above three stacked figures | 112 px ring beside a colour-keyed legend |
| Project cards (dashboards) | Status, budget and delivery date stacked | Status beside the title; budget beside delivery date |
| Home records | Figma's 44 px trailing blank under every task/notification | Removed |
| Account type | Two 190 px centred choice cards | One row per choice (icon, title, description, radio mark) |

Charts, complex rows ("Overview & Metrics" sentences), lists of records and
all actions keep full width.

Content height at 390 px, demo data (`test/features/ui_layout_survey_test.dart`,
`LAYOUT_REPORT=…`):

| Screen | Before | After | Saved |
|---|---:|---:|---:|
| Client home | 1922 | 1614 | 308 px (16 %) |
| Client dashboard | 4428 | 3810 | 618 px (13 %) |
| Client projects | 1937 | 1589 | 348 px (17 %) |
| Client invoices | 2021 | 1673 | 348 px (17 %) |
| Client payments | 2238 | 1907 | 331 px (14 %) |
| Employee home | 1922 | 1614 | 308 px (16 %) |
| Employee dashboard | 3452 | 3028 | 424 px (12 %) |
| Employee projects | 1928 | 1580 | 348 px (18 %) |
| Employee tasks | 3042 | 2640 | 402 px (13 %) |
| Employee timesheets | 3559 | 3133 | 426 px (11 %) |

Account type at 390×844: the screen no longer scrolls (Next was below the
fold before).

## 2. Language

- Choices: **System default**, **English**, **العربية**.
- System follows the device and its changes; an unsupported device language
  shows English (`resolveLocale`; Flutter's own fallback would have been
  Arabic, the first supported locale).
- A manual choice applies at once (RTL for Arabic) and keeps typed form
  values. Month names and AM/PM follow (`Intl.defaultLocale`); numeric dates
  and money keep Western digits.

## 3. Appearance

- Choices: **System default**, **Light**, **Dark**. System follows the
  device, including changes while the app is open.
- `AppPalette.light` holds the Figma variables; `AppPalette.dark` keeps the
  same roles on dark surfaces (brand blue `#2F7DF2` so white text stays
  ≥ 4:1, status tints and text readable). `AppColors`/`ModuleColors` read the
  active palette; `AppTheme.light()/dark()` build the Material theme from it
  (sheets, dialogs, menus, fields, snack bars, app bars).
- Backgrounds use `AppColors.surface`; `AppColors.white` is text/icons on
  blue or in the (always dark) meeting room; `AppColors.ink` replaces Figma's
  pure black titles. The logo's black wordmark turns white on dark pages.
- A change rebuilds every widget once and keeps state (routes, forms,
  scroll positions); status-bar icons follow.

## 4. Persistence

`wf.prefs.language` and `wf.prefs.appearance` in secure storage, separate
from `wf.session.*` (sign-out clears only the session). Read before the first
frame, so an override never flashes the default. One `preferencesProvider`
serves every control.

## 5. Controls

- Before sign-in (account type, login, register, password screens): two
  compact chips — the language in use, and Auto/Light/Dark.
- Inside the app: **More → Preferences** (both portals): Language and
  Appearance rows with the current value.
- Both open the same sheet; "System default" says it follows the device.

## 6. Redmi 8 acceptance

Build as in `docs/m06b-android-acceptance.md` (BUILD_SHA marker).

1. Phone language English, light: install, open — English, light.
2. Account type: both choices and **Next** visible without scrolling.
3. Tap **Auto** → **Dark**: everything turns dark at once; the selection
   stays. Tap the language chip → **العربية**: Arabic, right-to-left.
4. On Login, type an email, switch language and appearance: the email stays.
5. Kill and reopen the app: Arabic + dark remain. Set both back to
   **System default**.
6. Android Settings → Display → Dark theme on/off with WorkFlow open: the
   app follows. Set the phone language to Arabic, then French: the app shows
   Arabic, then English.
7. Sign in; **More → Preferences**: change Appearance and Language; sign out
   from the avatar menu — the choices remain on the sign-in screens.
8. Home, Dashboard, Projects, Invoices, Payments, Tasks, Timesheets in light
   and dark, English and Arabic: statistics show as compact groups (2–3 per
   row), no clipped numbers, no overflow, nothing under the navigation bar,
   `—` while loading (never a made-up 0).
9. Meeting room stays dark in both themes; chats, sheets, dialogs, date
   pickers and snack bars are readable in dark.

## 7. Known gaps

- Arabic text cannot be checked in the cloud screenshots (the test font has
  no Arabic glyphs); layout direction is verified, glyphs need the device.
- Images and illustrations (masthead sky, company icons) are unchanged in
  dark mode.
- Demo data (task titles, sample notifications) is English in both
  languages by design.
- The dark palette is derived from the light Figma roles; the Figma file has
  no mobile dark frames to compare against.
