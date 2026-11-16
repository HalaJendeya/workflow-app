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

## 8. Task cards

`TaskCard` (`work_widgets.dart`) replaces the stacked label-over-value card
in the Tasks list (demo and API); the Kanban cards (demo and API) are
compacted the same way.

| Card | Layout | Height at 390 px | Whole cards on a 390×844 screen |
|---|---|---:|---:|
| Tasks list | before: 7 labelled rows + 2 tinted 44 px buttons | 431 | 1 |
| Tasks list | after: title + status badge · code · sprint · project · icon metadata with 40 px edit/delete icons | 143 | 4 |
| Kanban | before: code / title / subtasks bar / divider / priority + duration | 144 | 1 |
| Kanban | after: code + priority + points tags / title / subtasks bar inline with duration and avatar | 106 | 1 (column header and tabs take the rest) |
| Dashboard focus | unchanged (already compact) | 116 | 3 |

- Padding 14/12/6/6 (was 20 all round); gap between cards 12 (was 20).
- Title up to 3 lines, identifier line up to 2, metadata values up to 2:
  long content wraps, nothing is cut off at 320 px with 130 % text.
- Each metadata item is announced as "Label: value"; the card itself is one
  button opening the details; edit/delete keep their keys and tooltips and
  are hidden without permission.
- Dates and times are a left-to-right isolate, so they keep their order in
  Arabic; a range like `09:30–11:30` never breaks in the middle.
- Kanban: tap still opens the move sheet; `canMove`/pending rules unchanged;
  high priority uses the danger colour.

Checks: `test/features/task_card_layout_test.dart` (light/dark × English/
Arabic at 320×640 ×1.3, 360×800, 390×844; `TASK_REPORT=…` for the figures).

Redmi 8: open Tasks, Sprints → Kanban and Dashboard in English and Arabic,
light and dark: badges at the top end, no cut-off dates or names, edit and
delete easy to hit, tapping a card opens its details.

## 9. Tasks: My Tasks first, details on demand

Supersedes the card layout of §8 for the Tasks list (Kanban and dashboard
cards are unchanged).

- **Scope.** The Tasks screen opens on **My tasks**; **Team tasks** is the
  second chip. API mode sends `assigned_to = <signed-in users.id>` to
  `GET /employee/tasks` (rows and figures) and keeps only rows whose
  `assignee.id` is that user; anything else is left out with a notice
  (gap E7). Demo mode: the demo account's tasks ("Demo User").
- **Card.** Title (up to 3 lines) with the status at the top end, the
  description (2 lines, only when the task has one) and the due date (only
  when it has one — API tasks never do). No code, sprint, project,
  priority, time, points, assignee or cost; no buttons. The whole card
  opens the details (announced "Opens the task details").
- **Details** (a page, not a sheet). A fixed bar with back and, when
  allowed, the actions menu (Edit, Delete — demo only). Then title, status
  with **Change status**, the full description ("No description" when
  none), subtasks (demo), Work details (task, project, sprint, priority,
  assignee, story points) and Schedule and time (due date, planned date,
  start, end, duration) — only fields the task has. No cost for employees.
  API mode reads `GET /employee/tasks/{task}`; change status uses
  `POST /employee/kanban/update-status` and appears only with
  `can.update: true`; refusals are shown.
- **Elsewhere.** Kanban (demo and API) keeps drag-and-drop and the move
  sheet; the sheet gains **View details**, and a task the user may not move
  opens its details instead of doing nothing. The dashboard's focus list
  shows the employee's own tasks and opens the same details.

| Card at 390 px | Height |
|---|---:|
| First version (labels over values) | 431 |
| §8 compact card | 143 |
| Title, description and due date | 135 |
| Title and status only | 59 |

Redmi 8 (API build): Tasks opens on My tasks with only your tasks; Team
tasks shows the rest; tap a task → details; back returns to the same
place; Change status shows only where allowed and reports a refusal; no
Edit/Delete for API tasks; English/Arabic, light/dark, 130 % text.

