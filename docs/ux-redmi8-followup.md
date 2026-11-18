# Redmi 8 UX acceptance follow-up (2026-11-18)

Input: the owner's API-mode run of `97f115c` on a Redmi 8, where 10 of 12
checks passed. This round fixed the two failed screens and audited
navigation. The work is Flutter-only: no API contract changed, and no live
request was sent.

## 1. Tasks: one Filters sheet (`e132ba9`)

| Before | After |
|---|---|
| Five status chips (All, To do, In Progress, Under Review, Completed) always visible, plus a Filters button below them | No status chips on the screen. **Status** is the first section of the Filters sheet |
| Sheet: project, priority, assignee (demo), sort | Sheet: **status**, project, priority, assignee (demo), sort, drafted and applied together with **Show results** |
| Status counts on the chips | Counts on the sheet's status choices. They hide while a search or another drafted filter would make them wrong |

The screen now shows: masthead search, My/Team (project leads only), the
summary card, **Filters (n)** with removable active-filter chips (status
included) and **Reset filters**, then the rows. Task cards show the title,
description and status.

Measured in API mode for a project lead with mocked data. At 360×800 the
first task row starts at 487 px instead of 573 px (−86 px), and three cards
are visible above the bar instead of one and a half. At 320×640 with 130%
text it starts at 604 px instead of 746 px (−142 px).

What stays the same: `status`, `project_id`, `priority` and `sort` go to
`GET /employee/tasks`. My Tasks sends `assigned_to`. An applied change
starts on page 1. Dismissing the sheet, or applying it unchanged, sends no
request.

## 2. Meeting Details: responsive facts (`a273f33`)

Both presentations use the same layout: the API screen (Client and
Employee) and the demo screen. It is built from a shared `MeetingFactsCard`
and a new core `DetailGrid`.

- **Timing** group: scheduled, duration, started, ended. **Details**
  group: type, privacy, project, creator, peak and max participants.
- The column count depends on the width at the current text size (a cell
  of 132 dp × the text scale): 2 on phones and 4 on a 768 dp tablet. If
  only one column fits, as at 320 dp with 130% text, each fact becomes one
  label…value line.
- Times read `2026/10/22 14:30`, isolated left-to-right for Arabic.
- Enabled features show as plain badges. They were inert chips that
  looked tappable.
- Participants take one line each, with host and connection badges at the
  end. Refresh is an icon in the card header.
- Join, Leave, join requests, your invitation, the employee-only
  invitations card and the demo's invite button are unchanged.

Facts card height, from a mocked live meeting in English (widget-test
measurement):

| Viewport | Before | After | Change |
|---|---|---|---|
| 320×640, text 1.3 | 1164 px | 988 px | −15% |
| 360×800 | 876 px | 625 px | −29% |
| 390×844 | 859 px | 625 px | −27% |
| 768×1024 | 839 px | 491 px | −41% |

Whole page at 360×800: 1887 px before, 1531 px after.

## 3. Navigation audit (`300f78a`)

How the app navigates:

- Tabs are a `StatefulShellRoute.indexedStack`. The bar, More's tab
  entries (employee: Projects, Sprints, Conversations; client: Companies,
  Invoices, Conversations) and the dashboard cards switch tabs with
  `go`/`goBranch`.
- More's other entries (Dashboard, Tasks, Timesheets, Meetings; client
  Dashboard, Payments, Projects, Meetings) and Home's "All tasks" push
  onto the tab's own navigator, so the bar stays and the tab keeps them.
- Details screens are pushed above the shell on the root navigator: Task
  Details, task lists, the board, the meeting room and forms. Project
  details and filters are root bottom sheets.

| # | Flow | Before | After |
|---|---|---|---|
| N1 | More → Projects / Sprints / Chat → Back | **App closed** (a `go` leaves nothing to pop) | Back to More |
| N2 | Client More → Companies / Invoices / Chat → Back | **App closed** | Back to More |
| N3 | Dashboard → View backlog (Sprints) → Back | **App closed**, Dashboard lost | Back to the Dashboard |
| N4 | More → Tasks, tap Chat, Back | **App closed** | Back to More with Tasks and its filters still open |
| N5 | Repeated tab switches, then Back | **App closed** | Each visited tab once, newest first, then Home, then exit |
| — | More → Tasks → Task Details → Back → Back | OK | OK: filter kept, then More |
| — | More → Meetings → Meeting Details → Back | OK | OK |
| — | Filters sheet open → Back | OK (sheet closes) | OK |
| — | Projects → Project Details sheet → Related tasks → Task Details → Back | OK: root pushes above the root sheet | Unchanged |

Fix: `AppShell` records the visited tabs and handles Back. If nothing can
be popped first (no pushed screen, sheet or dialog), Back goes to the
previous tab, then Home. Only Home's Back exits. No new floating button
was added.

Not changed, by design: where details screens sit (root versus tab
navigator).

> Correction (Android 16 emulator acceptance, see
> `android-emulator-acceptance.md`): this note originally claimed that
> re-tapping the current tab returned it to its first screen. It did not do
> that for screens pushed from More; `dd08c75` fixed it. The same run found
> that on Android 13+ predictive Back closed the app before `AppShell` saw
> the press; `4691964` fixed that.

## 4. Tests added or changed

- `task_filters_test.dart`, `m01_employee_smoke_test.dart`: status set
  through the sheet; four filters in one request; removing the status
  chip; counts hide while a project is drafted.
- `meeting_details_layout_test.dart`: column counts; grouped timing at
  360; one line per fact at 320 × 1.3; a row of four on a tablet; the
  participants row and header refresh; Client versus Employee controls;
  Arabic dark at 4 sizes with no overflow; the demo screen.
- `navigation_flow_test.dart`: 10 system-Back flows for both roles. Six
  of them failed before the fix.

## 5. Still open

- S1 and S2 backend security issues (`backend-security-issues-s1-s2.md`):
  unchanged and still open.
- On-device confirmation of this round on the Redmi 8.
- Onboarding and help: proposal only (`onboarding-help-proposal.md`).
