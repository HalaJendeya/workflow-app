# Employee — remaining documented features (2026-11-18)

| | |
|---|---|
| Base | `fff3983` on `feat/m01-batch2-emulator-fixes` (emulator-accepted) |
| Contract | Postman `WorkFlow`, uid `56083386-d0da80f4-f067-42e4-9b96-9e021769e55e`, **updatedAt 2026-11-14T11:14:33Z** (re-read in full 2026-11-18: unchanged since the M07 audit) |
| Backend | `https://api.workflownets.com` (production) |
| Live checks | Read-only `GET`s only, with the two QA employee tokens (lead, regular member; company 1). No write, join, read-marking, export of other users' data or join request was sent. |
| Not started | M08, onboarding walkthrough |

## 1. Contract verification (Phase 1)

The Employee folder (`04 Employee`) has 303 requests. For the six
requested features every route is documented, usable by the employee role
(not in Permission Boundary) and answered as below on 2026-11-18:

| Feature | Route(s) | Documented | Live (read-only) |
|---|---|---|---|
| Timesheet rows | `GET /employee/timesheets` (`month`, `status`, `page`) | Row fields named in prose; `stats`, `totals`, `available_months`, `facets` | 200 for both. Rows `{id, date, month, user, company, payment_type, rate, hours_minutes, total, currency, status, can}`; `hours_minutes` = **total minutes** (9600 = 160 h). `stats`/`totals`/`available_months` sit **beside** `data` |
| Timesheet details | `GET /employee/timesheets/{id}/details` | Full example (tasks grouped by project, `summary.in_sync`) | 200 for the owner (same keys as the example); **403** for another employee — ownership enforced |
| Employee report | `GET /employee/report` (`year`, `month` / `from`,`to`, `page`, `per_page`) | Full contract in the test (every section, cross-totals, forbidden keys) | 200 for both; all sections present |
| Notification subject | `GET /employee/notifications` | Only the **presence** of `subject` | `subject {type, id}`: `task` (`task_assigned`), `conversation` (`chat_message`), `meeting` (`meeting_invited`) |
| Join by code | `GET /employee/meetings/by-code/{code}` | `data {id}`; generic 404 for unknown/inaccessible | Unknown code → 404 "Meeting not found" |
| Own join request | `GET`/`DELETE /employee/meetings/{id}/join-request` | `GET`: `id, status, meeting_id`; 404 when none. `DELETE` ⚠️ | Not called (no QA approval meeting); `DELETE` never sent |
| CSV exports | `GET /employee/{projects,tasks,timesheets}/export`, `/sprints/backlog/export` | `text/csv` attachment, columns listed, pay columns removed for employees, 422 over 10 000 rows | tasks and timesheets: 200 `text/csv; charset=UTF-8`, `attachment; filename="…-2026-11-18.csv"`, BOM; tasks header has **no Cost/Currency**, as documented |
| Project members | `GET /employee/tasks/project-employees/{project}` | Only "`data` is a list" | Rows `{id, name}`; `id` is the **`users.id`** that `assigned_to` takes (the lead's own row carries the login user id; the regular member is in project 2 only) |

### Backend defects vs Flutter gaps

| Finding | Kind |
|---|---|
| The collection's `List Timesheets` test asserts `data.timesheets.data`, `data.summary`; the server (and the description) put the paginator in `data` and `stats` beside it | Contract defect (test out of date). The app follows the live shape and the description. |
| `summary.task_completion_rate` unit (0–1 or 0–100) undocumented | Contract gap. Not read: the app shows completed of total from the documented counts. |
| `project-employees` rows undocumented | Contract gap, now observed. Modelled strictly (`id` required). |
| Join-request `status` values other than `pending` undocumented | Contract gap. Only `pending` is interpreted; anything else is shown as sent. |
| Notification `subject` shape undocumented | Contract gap, observed. Unknown types open nothing. |
| Task details carry no `can` block | Contract gap (E17). A task opened by id (notification, report, timesheet) offers **no status change**, since `can.update` is unknown without the list row. |
| WhatsApp settings route | Backend defect: now answers 404 "The route … could not be found" (not deployed). |
| S1, S2 | Backend security defects, still present (§4). |
| Timesheet rows, details, report, notification navigation, join by code, own join request, CSV export, project-member assignees | **Flutter gaps** — all closed in this round (§2). |

## 2. Feature status

| # | Feature | Status | Where | Commit |
|---|---|---|---|---|
| 1 | Timesheet records and details | **Done** (mock-tested; list/details shapes from live) | More → Timesheets: status and month filters, record cards (Figma 729:38123), paging, **View** → tasks grouped by project with counted time, out-of-sync notice; each task opens its details | `d188969` |
| 2 | Employee Reports | **Done** (no Figma frame — needs design review) | More → Overview → **My report**: month/year with previous/next, figures, tasks by status, period tasks (paged, open details), projects with the user's role, timesheets, meetings | `b4a28e1`, `2332d16` |
| 3 | Notification navigation | **Done** | Home card and bell panel: tap marks read and opens the task, chat or meeting; a chevron marks items that open something | `8cf658e` |
| 4 | Join by code; own join request | **Done** (mock-tested) | Meetings list chip → **Join by Code** → meeting details (removed from More → Create on 2026-11-19: the + holds creation actions only). Meeting details: **Your join request** (waiting for host, Check again, Withdraw after confirmation) | `f1bd301` |
| 5 | CSV export | **Done** | One **Export CSV** chip beside the filters of Tasks, Projects, Timesheets and the Backlog; the list's current filters, every page; system save dialog | `1314dec` |
| 6 | Project-member-only assignees | **Done** | Task form assignee list = the chosen project's members; cleared when the project changes; error + Retry if it fails | `ea93973` |
| 7 | Report custom range (E27, 2026-11-20) | **Done** (mock-tested; no Figma frame) | My report → tap the period ("Choose dates") → date-range picker → `from`/`to` only (never with `year`/`month`); > 366 days refused before sending; previous/next off for a range. The label is the entry point because a third chip wraps the owner-reviewed controls card at 360 dp. | `f533faa` |

Not built (documented but out of scope or not usable): host-side join
request management (admit/reject/admit-all — employees cannot create
meetings and are not hosts in practice), meeting guest/public routes,
WhatsApp settings (O2), `GET /timesheets/{id}` (details
suffice; it returns the user record).

## 3. Navigation and UX (Phase 3)

- Existing Tasks, Meeting Details and Android Back behaviour unchanged;
  new pages are pushed on the root navigator, so Back returns to where
  they were opened (notification → task → Back → Home or bell panel).
- No new buttons where an action already existed: one export chip per
  list, placed after the Filters button; Join by code reuses the Figma
  chip; the report is one item under Overview.
- Empty, loading and failure states: every new list uses `AsyncSection`
  (spinner, localized error with Retry); empty states are specific
  ("You have no timesheets yet.", "No tasks are dated in this period.").
- Localized errors: export failures read "Couldn't export: <reason>";
  an unknown meeting code reads "No meeting with this code that you can
  open"; 403/404/422/500 use the central `localizedError`.
- Arabic RTL and dark mode: 44 new strings in both ARB files (one unused
  "totals only" string removed); directional
  insets only; chevrons rely on Material's own mirroring (a manual flip
  that double-mirrored the report arrows was fixed in `2332d16`).

## 4. Security and release blockers (Phase 5)

Re-checked 2026-11-18 with read-only GETs (values not printed):

| # | Status |
|---|---|
| **S1** (HIGH) | **Still open.** `GET /employee/sprints/2` as the regular member: 4 of 4 tasks carry a non-null `cost`. The app never calls this route (test-enforced). Not fixable in Flutter. |
| **S2** (HIGH) | **Still open.** The regular member (not on project 1) gets `GET /employee/projects/1` 200 with the client record (`credit_limit`) and users' emails, and `tasks/project-employees/1` 200. The app requests member lists only for projects the user **leads**; this does not fix the server. |
| Q1 / O1 | **Open** — may an assignee change their own task's status (`can.update: false` for the regular member)? Unchanged. |
| O2 | **Open** — WhatsApp settings route not deployed (404 "route could not be found"); confirm `WHATSAPP_NOTIFICATIONS_ENABLED` before any assignment test. |

Client-side hiding is **not** a fix for S1/S2.

## 5. Live mutations that need the owner's authorization

None of these was sent. Each needs explicit approval, a QA record, and
(for assignment) the WhatsApp check (O2):

| Action | Route | Why it matters |
|---|---|---|
| Mark a notification read by tapping it | `POST /employee/notifications/{id}/read` | Every tap of an unread item writes the read state (irreversible) |
| Open a chat from a notification | `POST …/conversations/{id}/read` | Opening a chat marks it read |
| Join with a code / join an approval meeting | `POST /employee/meetings/{id}/join` or `/media/join` | Creates a participant or a join request (202) |
| Withdraw my join request ⚠️ | `DELETE /employee/meetings/{id}/join-request` | Destructive |
| Create/edit a task with a project-member assignee | `POST`/`PUT /employee/tasks` | Real write; assignment may send WhatsApp |
| Exports (read-only, but they produce files with company data) | `GET …/export` | Allowed as GETs; files must not be shared outside QA |

## 6. Tests, builds and device check

| Step | Result (2026-11-18, Windows, local) |
|---|---|
| `dart format --set-exit-if-changed lib test` | clean |
| `flutter analyze` | No issues found |
| New tests | `employee_completion_test` (15: exports, members, timesheets, assignee form), `employee_report_test` (9), `notification_navigation_test` (8), `employee_meeting_join_test` (10), `employee_completion_layout_test` (3 modes × 6 screens) |
| Updated tests | M07 fake server answers `project-employees`; More/Meetings tests now expect Join by Code for employees; M01 smoke expects timesheet rows instead of the old "totals only" notice |
| Full suite (at `2c2410f`) | **1006 passed, 8 skipped, 1 failed**: `dashboard_profile_test` "Profile: rename…" **did not complete** under machine load (emulator booting); re-run alone: 3/3 passed. Profile code is unchanged. The earlier full run's only real failure (the M01 notice assertion) was fixed in `2c2410f`. |
| `flutter build web --no-web-resources-cdn --dart-define=APP_MODE=mock` | built |
| `flutter build apk --debug` (API mode, `BUILD_SHA=2c2410f`) | built |
| Android 16 emulator (Medium Phone API 36.1), API mode, the owner's existing employee session, **read-only navigation** | More shows **My report** (live figures; next period disabled at the current month); Timesheets shows the live row, filters and Export CSV; **View** opens the details (no counted tasks for a monthly payee); Back returns step by step; Meetings shows **join by code**; an unknown code gives the friendly 404 message; Tasks shows Filters + Export CSV in one row; Home shows the chevron on a task notification. No Flutter errors in logcat. Two copy nits found here were fixed in `36b44d8` (not re-installed). |
| Not done on the device | Tapping an unread notification (writes the read state), exporting/saving a file, joining, withdrawing a join request, the lead's task form, Arabic/dark on the device (covered by widget tests), the Redmi 8. |

Screenshots stayed local (they show the account's email).

## 7. Commits (local, not pushed)

`ea93973` assignees · `1314dec` CSV exports · `d188969` timesheets ·
`b4a28e1`, `2332d16` report · `8cf658e` notifications · `f1bd301` join by
code / join request · `bae3f71` layout tests · `2c2410f` test follow-up ·
`36b44d8` copy fixes · plus this documentation commit.

## 8. Recommended next phase

1. **Backend first**: fix S1 and S2 (release blockers), answer Q1 (assignee
   status rights) and deploy the WhatsApp settings route (O2); document
   E22–E25 in the collection.
2. **Authorized live mutation QA** (§5) on a dedicated QA project and an
   `approval` meeting, after the WhatsApp check.
3. **Design review** of My report (no Figma frame) and of non-leads now
   seeing the + button (Join by Code only).
4. Re-verify on the Redmi 8, then review the M08 scope.
